from fastapi import FastAPI, WebSocket, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession, create_async_engine
from redis.asyncio import Redis
#from graphql import GraphQLSchema
from elasticsearch import AsyncElasticsearch
import asyncio
from typing import *
import jwt

class PowerAPI:
    def __init__(self, config: dict = None):
        self.app = FastAPI()
        self.redis = Redis()
        self.elastic = AsyncElasticsearch()
        self.setup_all()

    def setup_all(self):
        # База данных
        self.db = create_async_engine("postgresql+asyncpg://")
        
        # Кэширование и очереди
        self.queue = asyncio.Queue()
        self.cache = {}
        
        # WebSocket комнаты
        self.rooms = defaultdict(set)
        
        # GraphQL схема
        self.schema = GraphQLSchema()
        
        # SSE менеджер
        self.sse_manager = SSEManager()
        
        # Менеджер задач
        self.task_manager = TaskManager()

    async def broadcast_to_room(self, room: str, message: Any):
        for ws in self.rooms[room]:
            await ws.send_json(message)

    def task(self, schedule: str = None):
        def wrapper(func):
            self.task_manager.add_task(func, schedule)
            return func
        return wrapper

    def graphql_resolver(self, field: str):
        def wrapper(func):
            self.schema.add_resolver(field, func)
            return func
        return wrapper

    def cache_result(self, ttl: int = 300):
        def wrapper(func):
            async def cached(*args, **kwargs):
                key = f"{func.__name__}:{args}:{kwargs}"
                if key in self.cache:
                    return self.cache[key]
                result = await func(*args, **kwargs)
                self.cache[key] = result
                return result
            return cached
        return wrapper

    async def search(self, index: str, query: dict):
        return await self.elastic.search(index=index, query=query)

    async def publish_event(self, channel: str, event: dict):
        await self.redis.publish(channel, event)

    def websocket_room(self, room: str):
        def decorator(websocket: WebSocket):
            async def wrapper():
                await websocket.accept()
                self.rooms[room].add(websocket)
                try:
                    while True:
                        data = await websocket.receive_json()
                        await self.broadcast_to_room(room, data)
                finally:
                    self.rooms[room].remove(websocket)
            return wrapper
        return decorator

    def sse_endpoint(self, channel: str):
        async def handler():
            async with self.sse_manager.subscribe(channel) as events:
                async for event in events:
                    yield event
        return handler

class TaskManager:
    def __init__(self):
        self.tasks = {}
        self.scheduler = AsyncIOScheduler()
        self.scheduler.start()

    def add_task(self, func, schedule=None):
        if schedule:
            self.scheduler.add_job(func, trigger=schedule)
        else:
            asyncio.create_task(func())

class SSEManager:
    def __init__(self):
        self.subscribers = defaultdict(set)
        
    async def emit(self, channel: str, data: Any):
        for queue in self.subscribers[channel]:
            await queue.put(data)

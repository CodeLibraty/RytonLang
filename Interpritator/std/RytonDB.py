import json
import uuid
import threading
import asyncio
from typing import Dict, List, Any, Optional
from pathlib import Path

class RytonDB:
    def __init__(self, path: str = "rytondb"):
        self.path = Path(path)
        self.storage: Dict[str, Dict] = {}
        self.indexes: Dict[str, Dict] = {}
        self.transactions: List = []
        self.lock = threading.Lock()
        self._load_data()
    
    def _load_data(self):
        if self.path.exists():
            with open(self.path, 'r') as f:
                self.storage = json.load(f)
    
    def _save_data(self):
        with open(self.path, 'w') as f:
            json.dump(self.storage, f)

    def create_collection(self, name: str):
        if name not in self.storage:
            self.storage[name] = {}
            self.indexes[name] = {}
            self._save_data()
            return True
        return False

    async def create(self, collection: str, document: dict) -> str:
        with self.lock:
            if collection not in self.storage:
                self.create_collection(collection)
            
            doc_id = str(uuid.uuid4())
            document['_id'] = doc_id
            self.storage[collection][doc_id] = document
            self._update_indexes(collection, doc_id, document)
            self._save_data()
            return doc_id

    async def read(self, collection: str, query: dict = None) -> List[dict]:
        with self.lock:
            if collection not in self.storage:
                return []
            
            if query is None:
                return list(self.storage[collection].values())
            
            return self._query_engine.execute(collection, query)

    async def update(self, collection: str, doc_id: str, document: dict) -> bool:
        with self.lock:
            if collection not in self.storage or doc_id not in self.storage[collection]:
                return False
            
            document['_id'] = doc_id
            self.storage[collection][doc_id] = document
            self._update_indexes(collection, doc_id, document)
            self._save_data()
            return True

    async def delete(self, collection: str, doc_id: str) -> bool:
        with self.lock:
            if collection not in self.storage or doc_id not in self.storage[collection]:
                return False
            
            del self.storage[collection][doc_id]
            self._remove_from_indexes(collection, doc_id)
            self._save_data()
            return True

    def _update_indexes(self, collection: str, doc_id: str, document: dict):
        for field in self.indexes[collection]:
            if field in document:
                self.indexes[collection][field][doc_id] = document[field]

    def _remove_from_indexes(self, collection: str, doc_id: str):
        for field_index in self.indexes[collection].values():
            if doc_id in field_index:
                del field_index[doc_id]

class QueryEngine:
    def __init__(self, db):
        self.db = db
    
    def execute(self, collection: str, query: dict) -> List[dict]:
        results = self.db.storage[collection].values()
        
        if 'where' in query:
            results = self._filter(results, query['where'])
        
        if 'sort' in query:
            results = self._sort(results, query['sort'])
            
        if 'limit' in query:
            results = list(results)[:query['limit']]
            
        return list(results)
    
    def _filter(self, documents, conditions):
        return [doc for doc in documents if self._match_conditions(doc, conditions)]
    
    def _match_conditions(self, doc, conditions):
        for field, condition in conditions.items():
            if isinstance(condition, dict):
                op = list(condition.keys())[0]
                value = condition[op]
                
                if op == '$gt':
                    if field not in doc or doc[field] <= value:
                        return False
                elif op == '$lt':
                    if field not in doc or doc[field] >= value:
                        return False
                elif op == '$in':
                    if field not in doc or doc[field] not in value:
                        return False
            else:
                if field not in doc or doc[field] != condition:
                    return False
        return True
    
    def _sort(self, documents, sort_params):
        return sorted(documents, 
                     key=lambda x: [x.get(field) for field in sort_params['fields']],
                     reverse=sort_params.get('desc', False))

class Transaction:
    def __init__(self, db):
        self.db = db
        self.operations = []
        
    async def begin(self):
        self.db.transactions.append(self)
        
    async def commit(self):
        if self in self.db.transactions:
            for op in self.operations:
                await op()
            self.db.transactions.remove(self)
            self.db._save_data()
            
    async def rollback(self):
        if self in self.db.transactions:
            self.operations.clear()
            self.db.transactions.remove(self)

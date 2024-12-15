import ray
import dask
import dask.dataframe as dd
import dask.array as da
from dask.distributed import Client, LocalCluster
from typing import Any, List, Dict, Callable

class DistributedComputing:
    def __init__(self):
        self.ray_initialized = False
        self.dask_client = None
        self.dask_cluster = None
        
    def init_ray(self, cpus: int = None, gpus: int = 0):
        ray.init(num_cpus=cpus, num_gpus=gpus)
        self.ray_initialized = True
        
    def init_dask(self, workers: int = 4, threads_per_worker: int = 2):
        self.dask_cluster = LocalCluster(
            n_workers=workers,
            threads_per_worker=threads_per_worker
        )
        self.dask_client = Client(self.dask_cluster)
        
    def parallel_map(self, func: Callable, data: List[Any], engine: str = 'ray') -> List[Any]:
        if engine == 'ray':
            @ray.remote
            def ray_func(x):
                return func(x)
            return ray.get([ray_func.remote(x) for x in data])
        else:
            return list(dask.compute(*[dask.delayed(func)(x) for x in data]))
            
    def load_dataframe(self, path: str, format: str = 'csv') -> dd.DataFrame:
        formats = {
            'csv': dd.read_csv,
            'parquet': dd.read_parquet,
            'json': dd.read_json
        }
        return formats[format](path)
        
    def create_array(self, data: np.ndarray, chunks: str = 'auto') -> da.Array:
        return da.from_array(data, chunks=chunks)
        
    def distribute_data(self, data: Any) -> Any:
        return ray.put(data) if self.ray_initialized else dask.delayed(data)
        
    def compute_graph(self, tasks: List[Dict]) -> Dict:
        if self.ray_initialized:
            @ray.remote
            def execute_task(task):
                return task['func'](*task['args'])
            return {
                task['name']: ray.get(execute_task.remote(task))
                for task in tasks
            }
        else:
            graph = {
                task['name']: dask.delayed(task['func'])(*task['args'])
                for task in tasks
            }
            return dask.compute(graph)[0]
            
    def get_cluster_info(self) -> Dict:
        if self.ray_initialized:
            return ray.cluster_resources()
        elif self.dask_client:
            return {
                'workers': len(self.dask_client.scheduler_info()['workers']),
                'memory': self.dask_client.scheduler_info()['memory'],
                'cpu': self.dask_client.scheduler_info()['cpu']
            }
        return {}

    def shutdown(self):
        if self.ray_initialized:
            ray.shutdown()
        if self.dask_client:
            self.dask_client.close()
            self.dask_cluster.close()

class Rask:
    def __init__(self):
        self.engine = DistributedComputing()
        
    def cluster(self, cpus: int = 4, workers: int = 2):
        self.engine.init_ray(cpus=cpus)
        self.engine.init_dask(workers=workers)
        return self

    def compute(self, func, data, engine='ray'):
        return self.engine.parallel_map(func, data, engine)
        
    def data(self, path: str, format: str = 'csv'):
        return self.engine.load_dataframe(path, format)
        
    def graph(self, tasks: list):
        return self.engine.compute_graph(tasks)

    def status(self):
        return self.engine.get_cluster_info()

# Создаем глобальный экземпляр для использования в Ryton
distributed = DistributedComputing()

# Глобальный экземпляр для Ryton
rask = Rask()

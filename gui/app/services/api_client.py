"""Julia 后端 HTTP 客户端"""

import requests
import json


class APIClient:
    def __init__(self, base_url="http://127.0.0.1:8765"):
        self.base_url = base_url

    def check_status(self) -> bool:
        try:
            r = requests.get(f"{self.base_url}/api/status", timeout=3)
            print(f"[DEBUG] check_status: {r.status_code} {r.text}")
            return r.status_code == 200
        except Exception as e:
            print(f"[DEBUG] check_status error: {e}")
            return False

    def get_algorithms(self) -> list:
        try:
            r = requests.get(f"{self.base_url}/api/algorithms", timeout=5)
            print(f"[DEBUG] get_algorithms: {r.status_code}")
            data = r.json()
            print(f"[DEBUG] algorithms: {json.dumps(data, indent=2, ensure_ascii=False)}")
            return data.get("algorithms", [])
        except Exception as e:
            print(f"[DEBUG] get_algorithms error: {e}")
            raise

    def repair(self, input_path: str, output_path: str,
               algorithm_id: str = "wavelet_gaussian_repair",
               params: dict = None,
               output_format: str = "wav") -> dict:
        body = {
            "mode": "repair",
            "algorithm_id": algorithm_id,
            "input_path": input_path,
            "output_path": output_path,
            "output_format": output_format,
            "params": params or {},
        }
        r = requests.post(f"{self.base_url}/api/run", json=body, timeout=300)
        return r.json()
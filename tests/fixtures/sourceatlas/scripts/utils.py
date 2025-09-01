#!/usr/bin/env python3

import os
import json
from typing import List, Dict, Any

class ConfigLoader:
    def __init__(self, config_path: str):
        self.config_path = config_path
        self.config = self._load_config()
    
    def _load_config(self) -> Dict[str, Any]:
        with open(self.config_path, 'r') as f:
            return json.load(f)
    
    def get_value(self, key: str) -> Any:
        return self.config.get(key)

def process_files(directory: str) -> List[str]:
    """Process all files in a directory."""
    result = []
    
    for root, dirs, files in os.walk(directory):
        for file in files:
            if not file.startswith('.'):
                result.append(os.path.join(root, file))
    
    return result

class DataProcessor:
    @staticmethod
    def transform(data: Dict[str, Any]) -> Dict[str, Any]:
        """Transform data according to rules."""
        return {k: v.upper() if isinstance(v, str) else v 
                for k, v in data.items()}

if __name__ == "__main__":
    print("Utility module loaded")
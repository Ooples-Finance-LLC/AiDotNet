# Python file with errors
import non_existent_module  # Import error
from typing import List

def process_data(data: List[str]) -> dict:
    result = {}
    for item in data:
        result[undefined_function(item)] = item  # NameError
    
    # Potential security issue
    password = "hardcoded_password_123"  # Security issue
    
    return result

class DataProcessor:
    def __init__(self):
        self.api_key = "sk_test_1234567890abcdef"  # Security issue
    
    def execute_query(self, user_input):
        # SQL injection vulnerability
        query = f"SELECT * FROM users WHERE name = '{user_input}'"
        return query

// TypeScript file with errors
import { Component } from 'react';  // Missing React import

class TestComponent {
    private missingType: NonExistentType;  // TS2304: Cannot find name
    
    constructor() {
        console.log(undefinedVariable);  // TS2304: Cannot find name
    }
    
    async fetchData() {
        const response = await fetch('/api/data');
        return response.json();
    }
}

export default TestComponent;

import pandas as pd
import numpy as np

#take input from user for supplier details and constraints for time and cost, then optimize the supplier selection based on the given constraints and weights for cost, time, risk and moq.
class SupplierOptimizer:
    def __init__(self, cost_weight=0.4, time_weight=0.4, risk_weight=0.1, moq_weight=0.1):
        self.weights = {
            'cost': cost_weight,
            'time': time_weight,
            'risk': risk_weight,
            'moq': moq_weight
        }
        self.suppliers = pd.DataFrame(columns=['id', 'name', 'cost', 'time', 'risk', 'moq'])

    def add_supplier(self, s_id, name, cost, time, risk, moq):
        new_row = {'id': s_id, 'name': name, 'cost': cost, 'time': time, 'risk': risk, 'moq': moq}
        self.suppliers = pd.concat([self.suppliers, pd.DataFrame([new_row])], ignore_index=True)

    def set_priority_mode(self, mode="balanced"):
        """
        Simulates 'Learning' by shifting weights based on the current business environment.
        """
        # In a real implementation, these weights would be learned from data and updated dynamically.
        # there should be no mode and weigths are user input 
        if mode == "crisis": # Focus entirely on speed and reliability
            self.weights = {'cost': 0.1, 'time': 0.6, 'risk': 0.2, 'moq': 0.1}
        elif mode == "budget": # Focus on lowest price
            self.weights = {'cost': 0.7, 'time': 0.1, 'risk': 0.1, 'moq': 0.1}
        else: # Balanced
            self.weights = {'cost': 0.4, 'time': 0.4, 'risk': 0.1, 'moq': 0.1}

    def optimize(self, max_time=None, max_cost=None, required_qty=None):
        if self.suppliers.empty:
            return "No suppliers available."

        # 1. HARD CONSTRAINTS (Effectivize by removing impossible choices first)
        df = self.suppliers.copy()
        
        if max_time:
            df = df[df['time'] <= max_time]
        if max_cost:
            df = df[df['cost'] <= max_cost]
        if required_qty:
            # Supplier must be able to handle our volume, but their MOQ shouldn't exceed our needs too much
            df = df[df['moq'] <= required_qty]

        if df.empty:
            return "No suppliers meet the required constraints (Time/Cost/MOQ)."

        # 2. NORMALIZATION (Min-Max Scaling)
        # We use a small epsilon to avoid division by zero if all suppliers have the same value
        for col in ['cost', 'time', 'risk', 'moq']:
            min_val = df[col].min()
            max_val = df[col].max()
            
            if max_val == min_val:
                df[f'norm_{col}'] = 0 # If all are same, they are all equally 'best'
            else:
                df[f'norm_{col}'] = (df[col] - min_val) / (max_val - min_val)

        # 3. SCORING (Weighted Sum Model)
        # Using a sum is better than a product here because it allows for trade-offs
        df['total_score'] = (
            (self.weights['cost'] * df['norm_cost']) +
            (self.weights['time'] * df['norm_time']) +
            (self.weights['risk'] * df['norm_risk']) +
            (self.weights['moq'] * df['norm_moq'])
        )

        # 4. RANKING
        # Sort by score ascending (Lower is Better)
        results = df.sort_values(by='total_score').reset_index(drop=True)
        
        # Add a helpful 'Recommendation' tag
        results['status'] = "Viable"
        results.loc[0, 'status'] = "BEST CHOICE"
        
        return results[['status', 'name', 'cost', 'time', 'risk', 'moq', 'total_score']]

# --- Example of "Best Possible" Use ---
optimizer = SupplierOptimizer()

# Add various suppliers
optimizer.add_supplier(1, "Global Logistics Co", cost=500, time=20, risk=0.2, moq=100)
optimizer.add_supplier(2, "Local Fast-Track", cost=1200, time=30, risk=0.1, moq=50)
optimizer.add_supplier(3, "Budget Sea-Freight", cost=300, time=
                       5, risk=0.5, moq=500)
optimizer.add_supplier(4, "City-Side Supply", cost=900, time=50, risk=0.05, moq=25)

# SITUATION: A critical disruption is detected 
# We need the product within 10 days, budget is $1000.
print("--- DISRUPTION OPTIMIZATION (Max 10 days, Mode: Crisis) ---")
optimizer.set_priority_mode("crisis")
results = optimizer.optimize(max_time=10, max_cost=1000)

print(results)
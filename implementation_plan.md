# Goal Description
The objective is to implement a Discrete Event Simulation (DES) framework in [DES.py](file:///home/paarth/SCDO/DES.py) for modeling supply chains. The simulation will take a sequence of locations (pincodes) and the modes of transport between them, forming a detailed route. 

The framework needs to handle specialized scenarios during transit, such as vehicle changes, state border crossings, and customs clearance procedures, modeling the associated delays and logic for each. To reflect real-world logistics, time delays and costs will follow probability distributions.

## Proposed Changes

### 1. User Input and Routing Logic
The simulation flow will be constructed dynamically from user input:
- **Locations**: An array of `n` locations (pincodes).
- **Transport Modes**: An array of `n-1` modes of transport linking these locations.
The engine will map this sequence into a series of [Node](file:///home/paarth/SCDO/DES.py#21-29) and [Link](file:///home/paarth/SCDO/DES.py#94-102) instances.

### 2. Node Implementations
We will expand the concept of a [Node](file:///home/paarth/SCDO/DES.py#21-29) to handle various in-transit events and state changes.

#### [MODIFY] [DES.py](file:///home/paarth/SCDO/DES.py) 
The following Nodes will be added:
- **`Origin/Destination Node`**: The start and end points of the supply chain routing.
- **`Transshipment Node`**: A node automatically placed when the transport mode changes (e.g., from Road to Rail). Simulates unloading, temporary storage, and reloading delays.
- **`Customs Node`**: Simulates international or special zone border crossings. Introduces clearance procedures.
- **`State Border Node`**: Transitions between states (e.g., UP to Jammu). Simulates regulatory check-posts.

### 3. Link (Transportation) Implementations
The [Link](file:///home/paarth/SCDO/DES.py#94-102) class will represent the journey between two nodes based on the specified transport mode.
- **[TransportLink](file:///home/paarth/SCDO/DES.py#65-75)**: Base class.
- **Subtypes**: [RoadLink](file:///home/paarth/SCDO/DES.py#76-84), [RailLink](file:///home/paarth/SCDO/DES.py#85-93), [AirLink](file:///home/paarth/SCDO/DES.py#94-102), [ShipLink](file:///home/paarth/SCDO/DES.py#103-111) (Sea transport).

### 4. Probabilistic Variables (Time and Cost)
To accurately simulate real-world uncertainties, the `time_delay` at both Nodes and Links will be sampled from specific probability distributions.

#### Time Delay Distributions by Transportation Link:
- **Road (Trucks)**: **Lognormal** (`random.lognormvariate`) – Accounts for typical travel times plus a long tail for unexpected traffic or breakdowns.
- **Rail (Trains)**: **Uniform** (`random.uniform`) – Tightly bounded between best-case and worst-case scenarios based on strict schedules.
- **Air (Cargo)**: **Normal** (`random.normalvariate`) – Highly predictable, tightly clustered around the scheduled flight time.
- **Ship (Sea Cargo)**: **Triangular** or **Weibull** – Represents a most-likely transit time but accounts for rare, massive delays due to ocean weather.

#### Time Delay Distributions by Node:
- **Customs Clearance**: **Exponential** (`random.expovariate`) or **Gamma** – Most shipments clear quickly, but a small percentage face massive delays due to inspections.
- **Transshipment**: **Normal** (`random.normalvariate`) – Unloading/reloading is generally a consistent process with small, symmetrical variations.
- **State Borders**: **Uniform** (`random.uniform`) – Distributed between an empty queue (fast) and a long queue (slow).

#### Cost Variables:
- **`cost_incurred`**: Rather than sampling an independent variable, cost is a deterministic function of the delay. Modeled as: `Fixed Base Cost + (Variable Rate * time_delay)`

### 5. Core Simulation Engine Update
- **[RouteParser](file:///home/paarth/SCDO/DES.py#113-153)**: A new component to ingest the input arrays, instantiate the required nodes, and link them properly.
- **Entity Traversal**: An entity (the shipment) will traverse the generated route, logging its entry and exit times at each [Node](file:///home/paarth/SCDO/DES.py#21-29) and [Link](file:///home/paarth/SCDO/DES.py#94-102).
- **`ShipmentTracker`**: A logger to track total lead time, accumulated costs, and the shipment's current state (e.g., "In Transit", "At Customs").

## Implementation Steps
1. Set up the dynamic [RouteParser](file:///home/paarth/SCDO/DES.py#113-153) to construct the node-link sequence from parallel arrays.
2. Build out the base [Node](file:///home/paarth/SCDO/DES.py#21-29) and specialized subclasses ([CustomsNode](file:///home/paarth/SCDO/DES.py#45-54), [TransshipmentNode](file:///home/paarth/SCDO/DES.py#35-44), [StateBorderNode](file:///home/paarth/SCDO/DES.py#55-63)).
3. Build the [Link](file:///home/paarth/SCDO/DES.py#94-102) subclasses for different transport types, including [ShipLink](file:///home/paarth/SCDO/DES.py#103-111).
4. Integrate probability distribution samplers for `time_delay` and `cost_incurred`.
5. Integrate with `simpy` to run the events and track execution time and track accumulated costs.

## User Review Required
> [!IMPORTANT]
> The plan is now updated with probabilistic modeling, the Ship transport mode, and removal of toll plazas. If this completely covers your requirements, please approve and we can start execution in [DES.py](file:///home/paarth/SCDO/DES.py).

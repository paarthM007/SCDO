from scdo.routing.router import list_cities, get_graph

graph = get_graph()
print(f"Nodes in graph: {len(graph.nodes)}")
results = list_cities("Mum")
print(f"Search 'Mum' results: {results}")
results = list_cities("New")
print(f"Search 'New' results: {len(results)} matches")
if results:
    print(f"First match: {results[0]}")


import re
import os

def parse_cities():
    py_file = 'd:/Google Solutions/SCDO/scdo/routing/cities_data.py'
    out_file = 'd:/Google Solutions/SCDO/scratch/world_cities_dart.txt'
    
    with open(py_file, 'r', encoding='utf-8') as f:
        content = f.read()

    # Find WORLD_CITIES list
    world_cities_match = re.search(r'WORLD_CITIES = \[(.*?)\]', content, re.DOTALL)
    if not world_cities_match:
        return

    world_cities_str = world_cities_match.group(1)
    
    lines = world_cities_str.strip().split('\n')
    
    countries = {}
    
    for line in lines:
        line = line.strip()
        if not line or line.startswith('#'):
            continue
            
        m = re.search(r'\("([^"]+)"\s*,\s*([-0-9.]+)\s*,\s*([-0-9.]+)\s*,\s*"([^"]+)"', line)
        if m:
            city_name = m.group(1)
            country_name = m.group(4)
            
            if country_name not in countries:
                countries[country_name] = []
            countries[country_name].append(city_name)

    # Generate Dart code
    with open(out_file, 'w', encoding='utf-8') as f:
        country_idx = 100
        for country_name, cities in countries.items():
            country_id = f'country_w_{country_idx}'
            f.write(f"  ZoneCountry(\n")
            f.write(f"    id: '{country_id}',\n")
            f.write(f"    name: '{country_name}',\n")
            f.write(f"    states: [\n")
            f.write(f"      ZoneState(\n")
            f.write(f"        id: 'state_w_{country_idx}_1',\n")
            f.write(f"        name: '{country_name} Cities',\n")
            f.write(f"        cities: [\n")
            
            for city_idx, city_name in enumerate(cities):
                city_id = f'city_w_{country_idx}_1_{city_idx+1}'
                f.write(f"          ZoneCity(id: '{city_id}', name: '{city_name}'),\n")
                
            f.write(f"        ],\n")
            f.write(f"      ),\n")
            f.write(f"    ],\n")
            f.write(f"  ),\n")
            country_idx += 1

if __name__ == "__main__":
    parse_cities()

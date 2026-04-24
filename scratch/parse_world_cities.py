
import re

def parse_cities():
    with open('d:/Google Solutions/SCDO/scdo/routing/cities_data.py', 'r', encoding='utf-8') as f:
        content = f.read()

    # Find WORLD_CITIES list
    world_cities_match = re.search(r'WORLD_CITIES = \[(.*?)\]', content, re.DOTALL)
    if not world_cities_match:
        print("WORLD_CITIES not found")
        return

    world_cities_str = world_cities_match.group(1)
    
    # Regex to find tuples: ("Name", lat, lon, "Country", is_port, is_airport)
    # Note: some names have single quotes like "Xi'an" or "Nuku'alofa"
    tuple_regex = r'\("([^"]+)"|(\'[^\']+\')\s*,\s*([-0-9.]+)\s*,\s*([-0-9.]+)\s*,\s*"([^"]+)"\s*,\s*(True|False)\s*,\s*(True|False)\)'
    
    # Actually, let's just split by lines and parse carefully
    lines = world_cities_str.strip().split('\n')
    
    countries = {}
    
    for line in lines:
        line = line.strip()
        if not line or line.startswith('#'):
            continue
            
        # Match pattern: ("City", lat, lon, "Country", bool, bool)
        # Using a more robust regex for the whole line
        m = re.search(r'\("([^"]+)"\s*,\s*([-0-9.]+)\s*,\s*([-0-9.]+)\s*,\s*"([^"]+)"', line)
        if m:
            city_name = m.group(1)
            lat = m.group(2)
            lon = m.group(3)
            country_name = m.group(4)
            
            if country_name not in countries:
                countries[country_name] = []
            countries[country_name].append(city_name)

    # Generate Dart code
    dart_code = ""
    country_idx = 100 # Start indexing countries from 100
    for country_name, cities in countries.items():
        country_id = f"country_w_{country_idx}"
        dart_code += f"  ZoneCountry(\n"
        dart_code += f"    id: '{country_id}',\n"
        dart_code += f"    name: '{country_name}',\n"
        dart_code += f"    states: [\n"
        dart_code += f"      ZoneState(\n"
        dart_code += f"        id: 'state_w_{country_idx}_1',\n"
        dart_code += f"        name: '{country_name} Cities',\n"
        dart_code += f"        cities: [\n"
        
        for city_idx, city_name in enumerate(cities):
            city_id = f"city_w_{country_idx}_1_{city_idx+1}"
            dart_code += f"          ZoneCity(id: '{city_id}', name: '{city_name}'),\n"
            
        dart_code += f"        ],\n"
        dart_code += f"      ),\n"
        dart_code += f"    ],\n"
        dart_code += f"  ),\n"
        country_idx += 1
        
    print(dart_code)

if __name__ == "__main__":
    parse_cities()

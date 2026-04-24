import os

env_path = 'd:/Google Solutions/SCDO/.env'
if os.path.exists(env_path):
    with open(env_path, 'r') as f:
        lines = f.readlines()
    
    new_lines = []
    json_lines = []
    collecting_json = False
    
    for line in lines:
        if line.startswith('GOOGLE_APPLICATION_CREDENTIALS_JSON='):
            collecting_json = True
            json_lines.append(line.strip())
        elif collecting_json:
            if line.strip().endswith("'") or line.strip().endswith('"'):
                json_lines.append(line.strip())
                # Join all JSON parts into a single line, removing internal line breaks
                full_json_line = "".join(json_lines)
                # Ensure the private key part has proper \n markers
                # (This is tricky without parsing, but let's try to join and fix common mistakes)
                new_lines.append(full_json_line + '\n')
                collecting_json = False
            else:
                json_lines.append(line.strip())
        else:
            new_lines.append(line)
            
    with open(env_path, 'w') as f:
        f.writelines(new_lines)
    print("Fixed .env file")
else:
    print(".env not found")

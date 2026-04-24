import os
import json
from scdo.db import get_db
from scdo.config import FIRESTORE_CACHE_COLLECTION

def dump_cache():
    db = get_db()
    cache_ref = db.collection(FIRESTORE_CACHE_COLLECTION)
    docs = cache_ref.stream()
    
    results = []
    for doc in docs:
        results.append({
            "id": doc.id,
            "data": doc.to_dict()
        })
    
    print(json.dumps(results, indent=2, default=str))

if __name__ == "__main__":
    dump_cache()

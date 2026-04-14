import json
import asyncio
import websockets

async def create_new_helpers():
    url = "ws://192.168.0.126:8123/api/websocket"
    token = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiI4MDhjN2M3NDIxNjc0ZjQ2Yjk2YWI1YTY3MWNiOWYyMSIsImlhdCI6MTc3NTkzODU2OSwiZXhwIjoyMDkxMjk4NTY5fQ.ttRF2gDFhvziMlm98Wr3Q-O7shQ-P6O9BkbXLqQpWyE"
    
    async with websockets.connect(url) as websocket:
        await websocket.recv()
        await websocket.send(json.dumps({"type": "auth", "access_token": token}))
        await websocket.recv()

        # Skapa Start-helper
        await websocket.send(json.dumps({
            "id": 1,
            "type": "config/input_number/create",
            "name": "Tvätt Start Wh",
            "min": 0,
            "max": 1000000,
            "step": 0.01,
            "mode": "box",
            "unit_of_measurement": "Wh"
        }))
        print(f"Skapar Start-helper: {await websocket.recv()}")

        # Skapa Stop-helper
        await websocket.send(json.dumps({
            "id": 2,
            "type": "config/input_number/create",
            "name": "Tvätt Stop Wh",
            "min": 0,
            "max": 1000000,
            "step": 0.01,
            "mode": "box",
            "unit_of_measurement": "Wh"
        }))
        print(f"Skapar Stop-helper: {await websocket.recv()}")

asyncio.get_event_loop().run_until_complete(create_new_helpers())

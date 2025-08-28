# API Documentation

The Emergency Response System API provides RESTful endpoints for managing emergency incidents, personnel, and resources.

## Base URL
```
http://localhost:3000/api/v1
```

## Authentication
Currently, the API does not require authentication. In production, implement appropriate authentication mechanisms.

## Endpoints

### Health Check
Check the system status and database connectivity.

**GET** `/api/health`

Response:
```json
{
  "success": true,
  "status": "healthy",
  "timestamp": "2025-01-27T10:00:00.000Z",
  "services": {
    "api": "running",
    "database": "connected"
  },
  "uptime": 3600
}
```

### Incidents

#### Get Active Incidents
Retrieve all currently active emergency incidents.

**GET** `/api/v1/incidents/active`

Response:
```json
{
  "success": true,
  "data": [
    {
      "id": 1,
      "incident_number": "INC-2025-000001",
      "incident_type": "Structure Fire",
      "severity": "High",
      "status": "Active",
      "longitude": -122.1630,
      "latitude": 37.4419,
      "address": "450 University Ave",
      "title": "Commercial Building Fire",
      "description": "Heavy smoke showing from building",
      "reported_at": "2025-01-27T10:00:00.000Z"
    }
  ],
  "count": 1,
  "timestamp": "2025-01-27T10:00:00.000Z"
}
```

### Personnel

#### Get Personnel Status
Retrieve current status and locations of emergency personnel units.

**GET** `/api/v1/personnel/status`

Response:
```json
{
  "success": true,
  "data": [
    {
      "unit_id": "PAFD-E01",
      "call_sign": "Engine 1",
      "unit_type": "Fire Engine",
      "status": "Available",
      "longitude": -122.1576,
      "latitude": 37.4614,
      "last_update": "2025-01-27T10:00:00.000Z"
    }
  ],
  "count": 1,
  "timestamp": "2025-01-27T10:00:00.000Z"
}
```

### Shelters

#### Get Available Shelters
Retrieve information about emergency shelters and their capacity.

**GET** `/api/v1/shelters/available`

Response:
```json
{
  "success": true,
  "data": [
    {
      "id": "SHELTER-01",
      "facility_name": "Mitchell Park Community Center",
      "facility_type": "Community Center",
      "longitude": -122.1549,
      "latitude": 37.4282,
      "address": "3700 Middlefield Rd, Palo Alto, CA",
      "total_capacity": 150,
      "current_occupancy": 0,
      "available_capacity": 150,
      "operational_status": "Available",
      "has_kitchen": true,
      "has_medical": true,
      "wheelchair_accessible": true,
      "contact_phone": "(650) 463-4920"
    }
  ],
  "count": 1,
  "timestamp": "2025-01-27T10:00:00.000Z"
}
```

## WebSocket Events

Connect to `ws://localhost:3000/ws` for real-time updates.

### Connection Event
```json
{
  "type": "connection",
  "message": "Connected to Emergency Response System",
  "timestamp": "2025-01-27T10:00:00.000Z"
}
```

### Update Event
```json
{
  "type": "update",
  "data": {
    "incident_id": 1,
    "status": "In Progress"
  },
  "timestamp": "2025-01-27T10:00:00.000Z"
}
```

## Error Handling

All API endpoints return errors in a consistent format:

```json
{
  "success": false,
  "error": {
    "code": "ERROR_CODE",
    "message": "Human-readable error message"
  }
}
```

### Common Error Codes
- `INTERNAL_ERROR` - Server error (500)
- `NOT_FOUND` - Endpoint not found (404)
- `RATE_LIMIT_EXCEEDED` - Too many requests (429)
- `VALIDATION_ERROR` - Invalid request data (400)

## Rate Limiting
- 1000 requests per hour per IP
- Headers included in responses:
  - `X-RateLimit-Limit`
  - `X-RateLimit-Remaining`
  - `X-RateLimit-Reset`

## CORS
Cross-origin requests are enabled for all origins in development. Configure appropriately for production.

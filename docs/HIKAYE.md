# GridPulse: The Energy World's Translator

Let me tell you about this project as a story. Imagine you're a software engineer at a large energy company in Australia.

---

## The Beginning of the Story: What's the Problem?

Your company has **10 different teams**:
- Analytics team (tracks market prices)
- Operations team (manages power plants)
- Risk team (forecasts threats)
- Reporting team (prepares reports for managers)
- ...and more

They all have a common need: **Energy production data**.

### The Old System (Nightmare Scenario)

```
AEMO (Australian Energy Market)
       │
       ├──────→ Analytics team wrote their own program
       ├──────→ Operations team wrote a different program
       ├──────→ Risk team used a completely different method
       └──────→ Every team fetches the same data differently!
```

**Problems:**
1. **Inconsistency**: Analytics team says "1250 MW solar energy", operations team says "1248 MW". Which is correct?
2. **Maintenance Nightmare**: 10 teams = 10 separate connection codes. When one breaks, who will fix it?
3. **Slowness**: If a new team requests data, weeks of integration work is required.
4. **No Traceability**: No one can answer "Why was the data 5 minutes late?"

---

## Solution: GridPulse Architecture

Now let me explain the system you've built. Think of it as setting up a **post office**:

```
┌─────────────────────────────────────────────────────────────┐
│                                                              │
│   AEMO (Energy Data)      Weather API                       │
│        📊                        🌤️                         │
│         │                         │                          │
│         └─────────┬───────────────┘                          │
│                   ▼                                          │
│   ┌─────────────────────────────────┐                        │
│   │      TRANSLATOR (webMethods)    │  ← Converts data to    │
│   │   "Reconciles different formats"│    standard format     │
│   └───────────────┬─────────────────┘                        │
│                   ▼                                          │
│   ┌─────────────────────────────────┐                        │
│   │     POST OFFICE (Kafka)         │  ← Stores and          │
│   │   "Stores, distributes messages"│    distributes messages│
│   │                                  │                        │
│   │   📬 market.dispatch mailbox    │                        │
│   │   📬 weather.observations mailbox│                        │
│   └───────────────┬─────────────────┘                        │
│                   ▼                                          │
│   ┌─────────────────────────────────┐                        │
│   │   SECURITY GUARD (Kong)         │  ← Who's entering?     │
│   │   "Checks ID at the door"       │    How many requests?  │
│   └───────────────┬─────────────────┘                        │
│                   │                                          │
│         ┌─────────┼─────────┐                                │
│         ▼         ▼         ▼                                │
│      Analytics  Operations  Risk                             │
│       Team       Team      Team                              │
│        👩‍💼        👨‍🔧       👨‍💻                              │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

---

## Step-by-Step: How Does It Work?

### Step 1: Data Collection (download_aemo.py)

Our story starts with AEMO. AEMO is the organization that manages Australia's national energy market. Every **5 minutes** it publishes this data:

- How much electricity is being produced in each region?
- Is it from solar panels, wind turbines, or coal plants?

```python
# Real data example:
{
    "region_id": "NSW1",          # New South Wales region
    "fuel_type": "solar",         # Solar energy
    "value_mw": 1250.5,           # 1250.5 Megawatt production
    "event_time": "2024-01-15T10:00:00Z"
}
```

We also fetch **weather data** (from Open-Meteo API):
- Temperature (affects air conditioning usage → electricity demand)
- Wind speed (how much do wind turbines produce?)
- Humidity

**Why is weather important?**
- On a hot day, everyone turns on air conditioning → electricity demand increases
- On a windy day, turbines produce more
- On a cloudy day, solar panels produce less

---

### Step 2: Standardization (Canonical Model)

Data from different sources comes in different formats. For example:
- AEMO: `"settlementDate": "2024/01/15 10:00:00"`
- Weather: `"time": "2024-01-15T10:00:00+11:00"`

We convert all data to **one standard format**:

```xml
<!-- MarketDispatchEvent.xsd - Standard format -->
<MarketDispatchEvent>
    <eventId>NSW1_SOLAR_20240115_1000</eventId>
    <eventType>MarketDispatchEvent</eventType>
    <eventTime>2024-01-15T10:00:00Z</eventTime>
    <regionId>NSW1</regionId>
    <fuelType>solar</fuelType>
    <valueMW>1250.5</valueMW>
    <correlationId>abc-123-def-456</correlationId>  <!-- Traceability ID -->
</MarketDispatchEvent>
```

**Why is this important?**
All teams receive data in the same format. No more "is your data correct or is mine?" debates!

---

### Step 3: Kafka - The Post Office

Think of Kafka as a **post office**:

```
┌─────────────────────────────────────────────┐
│              KAFKA POST OFFICE              │
├─────────────────────────────────────────────┤
│                                             │
│  📬 market.dispatch (3 partitions)         │
│     ├── Partition 0: NSW1 letters          │
│     ├── Partition 1: VIC1 letters          │
│     └── Partition 2: QLD1 letters          │
│                                             │
│  📬 weather.observations (3 partitions)    │
│     └── Each region's weather              │
│                                             │
│  📬 dlq.market.dispatch (Lost letters)     │
│     └── Undeliverable ones here            │
│                                             │
└─────────────────────────────────────────────┘
```

**Kafka's superpowers:**

1. **Durability**: Letters are stored for 7 days. If a team is on vacation, they can retrieve all letters when they return.

2. **Independence**: Even if the analytics team reads slowly, the operations team continues to read quickly.

3. **Replay**: "I want to see yesterday's data again" → Kafka can replay everything!

4. **Ordering**: Data from the same region is always in order. NSW1's 10:00 data always comes before 10:05.

---

### Step 4: Kong - Security Guard

Now the data is ready. But should we give it to everyone? No! Kong stands at the door:

```
Visitor: "I want the data!"
Kong: "Your ID card please?" (API Key)
Visitor: "analytics-team-secret-key-2024"
Kong: "Okay, you may pass. But you can't make more than 100 requests per minute!"
```

**Kong's duties:**

1. **Identity Verification (Authentication)**:
   ```bash
   # Without API key → FORBIDDEN!
   curl http://localhost:8100/v1/market/dispatch
   # Result: 401 Unauthorized

   # With API key → Welcome!
   curl -H "apikey: analytics-team-secret-key-2024" http://localhost:8100/v1/market/dispatch
   # Result: 200 OK + Data
   ```

2. **Rate Limiting**:
   If a team makes too many requests (like a DoS attack), Kong stops them.

3. **Traceability (Correlation ID)**:
   Assigns a unique number to each request. When there's a problem, you can track the entire system with this number.
   ```
   X-Correlation-ID: 23a99a8b-2e0b-491f-ac0c-4c38d7801da5
   ```

---

### Step 5: API Server - Data Server

A simple API written in Flask. It reads data from Kafka and serves it to teams:

```python
# Example endpoints:

GET /health              # Is the system healthy?
GET /api/v1/dispatch     # Energy production data
GET /api/v1/weather      # Weather data
GET /api/v1/stats        # Statistics
POST /api/v1/dispatch    # Add new data
```

**Example response:**
```json
{
    "data": [
        {
            "region_id": "NSW1",
            "fuel_type": "solar",
            "value_mw": 1250.5,
            "correlation_id": "abc-123"
        },
        {
            "region_id": "VIC1",
            "fuel_type": "wind",
            "value_mw": 890.3,
            "correlation_id": "def-456"
        }
    ],
    "meta": {
        "count": 2,
        "timestamp": "2024-01-15T10:05:00Z"
    }
}
```

---

## Real Data

This project uses **real-world data**:

### 1. AEMO Data (Energy Market)
- **Source**: Australian Energy Market Operator
- **Contains**: Every 5 minutes, electricity production in Australia's 5 regions (NSW, VIC, QLD, SA, TAS)
- **Fuel types**: Solar, wind, coal, gas, hydro, battery

### 2. Open-Meteo Data (Weather)
- **Source**: Open-Meteo API (free, no API key required)
- **Contains**: Temperature, wind speed, humidity
- **Cities**: Sydney, Melbourne, Brisbane, Adelaide, Hobart

---

## What Problems Does This System Solve?

| Problem | Old Situation | With GridPulse |
|---------|---------------|----------------|
| **Adding new team** | Takes weeks | Completed in 5 minutes |
| **Data inconsistency** | Each team sees different data | Everyone sees the same data |
| **Maintenance** | 10 separate systems to maintain | Single centralized system |
| **Traceability** | "Where did the data get lost?" | Track with correlation ID |
| **Data loss** | Messages can be lost | Zero loss with DLQ |
| **Security** | Everyone accesses everything | Control with API keys |

---

## End of the Story: Demo Scenarios

### Scenario 1: "Risk team also wants data!"

**Old world**: Meetings, approvals, weeks of coding...

**With GridPulse**:
```bash
# 1. Add new consumer in Kong (30 seconds)
curl -X POST http://localhost:8101/consumers --data username=risk-team
curl -X POST http://localhost:8101/consumers/risk-team/key-auth --data key=risk-secret-key

# 2. Test (5 seconds)
curl -H "apikey: risk-secret-key" http://localhost:8100/v1/market/dispatch

# Total time: 35 seconds! 🎉
```

### Scenario 2: "Something broke, where?"

You can track everything with correlation ID:
```
Request arrives → Kong logs it: correlation_id=abc-123
              → API Server logs it: correlation_id=abc-123
              → Added to Kafka header: correlation_id=abc-123

Problem? Search all logs for "abc-123", find it instantly!
```

---

## Summary

GridPulse, for complex energy data:
1. **Collects** (AEMO + Weather)
2. **Standardizes** (Canonical Model)
3. **Stores and Distributes** (Kafka)
4. **Protects** (Kong)
5. **Serves** (API Server)

While doing all this, it provides **traceability**, **security**, and **flexibility**.

This architecture is a practical implementation of **Enterprise Integration Patterns** used by large companies in the real world.

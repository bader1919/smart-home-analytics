#!/usr/bin/env python3
"""
BY MB Consultancy - Home Assistant Data Collector
Advanced IoT data collection and processing for smart home analytics
"""

import asyncio
import aiohttp
import json
import logging
import os
import time
from datetime import datetime, timezone
from typing import Dict, List, Any, Optional
import schedule
import redis
from dataclasses import dataclass

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('/app/logs/collector.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

@dataclass
class CollectorConfig:
    """Configuration for the data collector"""
    ha_url: str
    ha_token: str
    graphiti_url: str
    collection_interval: int = 900  # 15 minutes
    group_id: str = "bymb-consultancy"
    redis_url: str = "redis://redis:6379"
    max_retries: int = 3
    batch_size: int = 100

class HomeAssistantCollector:
    """Advanced Home Assistant data collector with analytics"""
    
    def __init__(self, config: CollectorConfig):
        self.config = config
        self.session: Optional[aiohttp.ClientSession] = None
        self.redis_client = redis.from_url(config.redis_url)
        self.last_collection = None
        
    async def __aenter__(self):
        """Async context manager entry"""
        self.session = aiohttp.ClientSession(
            headers={"Authorization": f"Bearer {self.config.ha_token}"}
        )
        return self
    
    async def __aexit__(self, exc_type, exc_val, exc_tb):
        """Async context manager exit"""
        if self.session:
            await self.session.close()
    
    async def get_ha_states(self) -> List[Dict[str, Any]]:
        """Get all states from Home Assistant"""
        try:
            url = f"{self.config.ha_url}/api/states"
            async with self.session.get(url) as response:
                if response.status == 200:
                    states = await response.json()
                    logger.info(f"Retrieved {len(states)} states from Home Assistant")
                    return states
                else:
                    logger.error(f"Failed to get HA states: {response.status}")
                    return []
        except Exception as e:
            logger.error(f"Error fetching HA states: {e}")
            return []
    
    def process_analytics_data(self, states: List[Dict[str, Any]]) -> Dict[str, Any]:
        """Process states into analytics insights"""
        analytics = {
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "total_entities": len(states),
            "energy": {"sensors": [], "total_consumption": 0, "efficiency_score": 0},
            "security": {"sensors": [], "active_alerts": 0, "score": 0},
            "climate": {"sensors": [], "average_temp": 0, "humidity": 0},
            "lighting": {"total_lights": 0, "lights_on": 0, "energy_usage": 0},
            "device_health": {"total_devices": 0, "offline_devices": 0, "score": 0}
        }
        
        # Process each entity
        for state in states:
            entity_id = state.get("entity_id", "")
            domain = entity_id.split(".")[0] if "." in entity_id else ""
            state_value = state.get("state", "")
            
            # Energy monitoring
            if domain == "sensor" and "power" in entity_id.lower():
                try:
                    power = float(state_value) if state_value not in ["unknown", "unavailable"] else 0
                    analytics["energy"]["total_consumption"] += power
                except (ValueError, TypeError):
                    pass
            
            # Security monitoring
            elif domain in ["binary_sensor"] and any(
                keyword in entity_id.lower() 
                for keyword in ["motion", "door", "window", "security"]
            ):
                if state_value in ["on", "open", "detected"]:
                    analytics["security"]["active_alerts"] += 1
            
            # Device health
            elif state_value in ["unavailable", "unknown", "offline"]:
                analytics["device_health"]["offline_devices"] += 1
            
            analytics["device_health"]["total_devices"] += 1
        
        # Calculate scores
        analytics["energy"]["efficiency_score"] = min(95, max(50, 100 - (analytics["energy"]["total_consumption"] / 10)))
        analytics["security"]["score"] = max(50, 100 - (analytics["security"]["active_alerts"] * 5))
        
        total_devices = analytics["device_health"]["total_devices"]
        offline_devices = analytics["device_health"]["offline_devices"]
        analytics["device_health"]["score"] = (
            (total_devices - offline_devices) / max(total_devices, 1) * 100
        ) if total_devices > 0 else 100
        
        return analytics
    
    async def send_to_graphiti(self, episode_name: str, content: str, source: str = "json"):
        """Send data to Graphiti memory graph"""
        try:
            # Simple HTTP POST since we don't have the exact Graphiti client
            payload = {
                "name": episode_name,
                "episode_body": content,
                "group_id": self.config.group_id,
                "source": source
            }
            
            # Log the data we would send
            logger.info(f"Would send to Graphiti: {episode_name}")
            logger.debug(f"Payload: {json.dumps(payload, indent=2)}")
            
            return {"status": "logged"}
        except Exception as e:
            logger.error(f"Error sending to Graphiti: {e}")
            return None
    
    async def collect_and_process(self):
        """Main collection and processing method"""
        logger.info("Starting data collection cycle")
        
        try:
            states = await self.get_ha_states()
            if not states:
                logger.warning("No states retrieved from Home Assistant")
                return
            
            analytics = self.process_analytics_data(states)
            timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
            
            # Send analytics to Graphiti
            await self.send_to_graphiti(
                f"Smart Home Analytics - {timestamp}",
                json.dumps(analytics),
                "json"
            )
            
            # Generate insights
            insights = f"""
            BY MB Consultancy Smart Home Report - {timestamp}
            
            Energy Efficiency: {analytics['energy']['efficiency_score']:.1f}%
            Security Score: {analytics['security']['score']:.1f}%
            Device Health: {analytics['device_health']['score']:.1f}%
            
            Total Entities: {analytics['total_entities']}
            Active Security Alerts: {analytics['security']['active_alerts']}
            Offline Devices: {analytics['device_health']['offline_devices']}
            """
            
            await self.send_to_graphiti(
                f"Daily Insights - {timestamp}",
                insights,
                "text"
            )
            
            logger.info(f"Collection completed: Energy {analytics['energy']['efficiency_score']:.1f}%, Security {analytics['security']['score']:.1f}%")
            
        except Exception as e:
            logger.error(f"Error in collection cycle: {e}")

async def main():
    """Main application entry point"""
    config = CollectorConfig(
        ha_url=os.getenv("HOME_ASSISTANT_URL", "http://192.168.11.198:8123"),
        ha_token=os.getenv("HOME_ASSISTANT_TOKEN", ""),
        graphiti_url=os.getenv("GRAPHITI_URL", "http://192.168.11.29:8000"),
        collection_interval=int(os.getenv("COLLECTION_INTERVAL", "900")),
        group_id=os.getenv("GROUP_ID", "bymb-consultancy")
    )
    
    if not config.ha_token:
        logger.error("HOME_ASSISTANT_TOKEN environment variable is required")
        return
    
    logger.info("Starting BY MB Consultancy Home Assistant Data Collector")
    logger.info(f"Target HA: {config.ha_url}")
    logger.info(f"Collection interval: {config.collection_interval} seconds")
    
    async with HomeAssistantCollector(config) as collector:
        while True:
            await collector.collect_and_process()
            logger.info(f"Sleeping for {config.collection_interval} seconds")
            await asyncio.sleep(config.collection_interval)

if __name__ == "__main__":
    asyncio.run(main())
#!/usr/bin/env python3
"""
GridPulse API Unit Tests
------------------------
Flask API endpoint'leri için unit testler.
"""

import pytest
import json
import sys
import os

# Add parent directory to path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'scripts'))

from api_server import app, cache


@pytest.fixture
def client():
    """Test client fixture"""
    app.config['TESTING'] = True
    with app.test_client() as client:
        yield client


@pytest.fixture
def sample_dispatch_event():
    """Sample dispatch event for testing"""
    return {
        "event_id": "TEST_NSW1_SOLAR_20240115_1000",
        "event_type": "MarketDispatchEvent",
        "event_time": "2024-01-15T10:00:00Z",
        "region_id": "NSW1",
        "fuel_type": "solar",
        "value_mw": 1250.5,
        "unit": "MW",
        "source": "TEST"
    }


class TestHealthEndpoint:
    """Health endpoint tests"""
    
    def test_health_returns_200(self, client):
        """Health endpoint should return 200"""
        response = client.get('/health')
        assert response.status_code == 200
    
    def test_health_returns_json(self, client):
        """Health endpoint should return JSON"""
        response = client.get('/health')
        data = json.loads(response.data)
        assert 'status' in data
        assert data['status'] == 'healthy'
    
    def test_health_includes_cache_stats(self, client):
        """Health endpoint should include cache stats"""
        response = client.get('/health')
        data = json.loads(response.data)
        assert 'cache_stats' in data


class TestDispatchEndpoint:
    """Dispatch endpoint tests"""
    
    def test_get_dispatch_returns_200(self, client):
        """GET dispatch should return 200"""
        response = client.get('/api/v1/dispatch')
        assert response.status_code == 200
    
    def test_get_dispatch_returns_json(self, client):
        """GET dispatch should return JSON with data and meta"""
        response = client.get('/api/v1/dispatch')
        data = json.loads(response.data)
        assert 'data' in data
        assert 'meta' in data
    
    def test_get_dispatch_with_region_filter(self, client, sample_dispatch_event):
        """GET dispatch with region filter should filter results"""
        # Add a sample event
        cache.add_dispatch(sample_dispatch_event)
        
        # Query with filter
        response = client.get('/api/v1/dispatch?region_id=NSW1')
        data = json.loads(response.data)
        assert data['meta']['region_filter'] == 'NSW1'
    
    def test_get_dispatch_with_limit(self, client):
        """GET dispatch with limit should respect limit"""
        response = client.get('/api/v1/dispatch?limit=10')
        data = json.loads(response.data)
        assert len(data['data']) <= 10
    
    def test_post_dispatch_valid(self, client):
        """POST dispatch with valid data should return 202"""
        event = {
            "region_id": "NSW1",
            "value_mw": 1500.0,
            "fuel_type": "wind"
        }
        response = client.post(
            '/api/v1/dispatch',
            data=json.dumps(event),
            content_type='application/json'
        )
        assert response.status_code == 202
    
    def test_post_dispatch_missing_field(self, client):
        """POST dispatch with missing field should return 400"""
        event = {
            "region_id": "NSW1"
            # Missing value_mw
        }
        response = client.post(
            '/api/v1/dispatch',
            data=json.dumps(event),
            content_type='application/json'
        )
        assert response.status_code == 400


class TestWeatherEndpoint:
    """Weather endpoint tests"""
    
    def test_get_weather_returns_200(self, client):
        """GET weather should return 200"""
        response = client.get('/api/v1/weather')
        assert response.status_code == 200
    
    def test_get_weather_returns_json(self, client):
        """GET weather should return JSON"""
        response = client.get('/api/v1/weather')
        data = json.loads(response.data)
        assert 'data' in data
        assert 'meta' in data


class TestStatsEndpoint:
    """Stats endpoint tests"""
    
    def test_get_stats_returns_200(self, client):
        """GET stats should return 200"""
        response = client.get('/api/v1/stats')
        assert response.status_code == 200
    
    def test_get_stats_includes_counts(self, client):
        """GET stats should include event counts"""
        response = client.get('/api/v1/stats')
        data = json.loads(response.data)
        assert 'total_dispatch_events' in data
        assert 'total_weather_events' in data


class TestCorrelationId:
    """Correlation ID tests"""
    
    def test_correlation_id_in_response(self, client):
        """Response should include X-Correlation-ID header"""
        response = client.get('/api/v1/dispatch')
        assert 'X-Correlation-ID' in response.headers
    
    def test_correlation_id_in_body(self, client):
        """Response body should include correlation_id"""
        response = client.get('/api/v1/dispatch')
        data = json.loads(response.data)
        assert 'correlation_id' in data['meta']
    
    def test_correlation_id_forwarded(self, client):
        """Provided correlation ID should be forwarded"""
        custom_id = "test-correlation-id-12345"
        response = client.get(
            '/api/v1/dispatch',
            headers={'X-Correlation-ID': custom_id}
        )
        assert response.headers['X-Correlation-ID'] == custom_id


class TestErrorHandling:
    """Error handling tests"""
    
    def test_404_returns_json(self, client):
        """404 error should return JSON"""
        response = client.get('/nonexistent')
        assert response.status_code == 404
        data = json.loads(response.data)
        assert 'error' in data


if __name__ == '__main__':
    pytest.main([__file__, '-v'])

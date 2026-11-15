from app import app

def test_health_endpoint():
    test_client = app.test_client()
    res = test_client.get("/health")
    assert res.status_code == 200
    assert res.get_json() == {"status": "ok"}

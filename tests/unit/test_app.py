import pytest

from app import create_app

@pytest.fixture()
def app():
        app = create_app()
        app.config.update({
                "TESTING": True,
        })

        yield app

@pytest.fixture()
def client(app):
        return app.test_client()

def test_explore(client):
        assert client
        response = client.get('/explore')
        print(response)
        assert response.status_code == 302

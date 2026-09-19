import json
import os

import httpx
import typer

app = typer.Typer(help="Governed platform control-plane client")
api_url = os.getenv("PLATFORM_API_URL", "http://127.0.0.1:8000")


@app.command()
def catalog():
    typer.echo(json.dumps(httpx.get(f"{api_url}/api/v1/catalog").json(), indent=2))


@app.command()
def status(environment_id: str):
    typer.echo(
        json.dumps(httpx.get(f"{api_url}/api/v1/environments/{environment_id}").json(), indent=2)
    )

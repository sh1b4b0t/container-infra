"""
Fluxo de autenticação OAuth2 para Google Tasks API.
Executado via: ./google-tasks-dev.sh auth
"""
import os

from google_auth_oauthlib.flow import InstalledAppFlow

SCOPES = ["https://www.googleapis.com/auth/tasks"]
TOKEN_FILE = os.environ.get("TOKEN_FILE", "/app/data/token.json")
CLIENT_ID = os.environ.get("GOOGLE_CLIENT_ID", "")
CLIENT_SECRET = os.environ.get("GOOGLE_CLIENT_SECRET", "")


def main():
    if not CLIENT_ID or not CLIENT_SECRET:
        print("❌ GOOGLE_CLIENT_ID e GOOGLE_CLIENT_SECRET devem estar no .env")
        return

    client_config = {
        "installed": {
            "client_id": CLIENT_ID,
            "client_secret": CLIENT_SECRET,
            "auth_uri": "https://accounts.google.com/o/oauth2/auth",
            "token_uri": "https://oauth2.googleapis.com/token",
            "redirect_uris": ["http://localhost:8090"],
        }
    }

    flow = InstalledAppFlow.from_client_config(client_config, SCOPES)

    print("Iniciando servidor OAuth2 na porta 8090...")
    print("Copie a URL abaixo e abra no seu navegador:")
    print("")

    creds = flow.run_local_server(
        host="localhost",
        bind_addr="0.0.0.0",
        port=8090,
        open_browser=False,
        success_message="Autenticação concluída! Pode fechar esta aba.",
    )

    os.makedirs(os.path.dirname(TOKEN_FILE), exist_ok=True)
    with open(TOKEN_FILE, "w") as f:
        f.write(creds.to_json())

    print("")
    print(f"✅ Token salvo em {TOKEN_FILE}")
    print("Agora execute: ./google-tasks-dev.sh start")


if __name__ == "__main__":
    main()

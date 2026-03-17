import os

from google.auth.transport.requests import Request
from google.oauth2.credentials import Credentials
from googleapiclient.discovery import build

SCOPES = ["https://www.googleapis.com/auth/tasks"]


class AuthError(Exception):
    pass


class GoogleTasksClient:
    def __init__(self):
        self._service = None

    def _get_service(self):
        token_file = os.environ.get("TOKEN_FILE", "/app/data/token.json")

        if not os.path.exists(token_file):
            raise AuthError(
                "Token não encontrado. Execute: ./google-tasks-dev.sh auth"
            )

        creds = Credentials.from_authorized_user_file(token_file, SCOPES)

        if not creds.valid:
            if creds.expired and creds.refresh_token:
                creds.refresh(Request())
                with open(token_file, "w") as f:
                    f.write(creds.to_json())
                self._service = None
            else:
                raise AuthError(
                    "Token inválido ou expirado. Execute: ./google-tasks-dev.sh auth"
                )

        if self._service is None:
            self._service = build("tasks", "v1", credentials=creds)

        return self._service

    def list_task_lists(self) -> list[dict]:
        service = self._get_service()
        results = service.tasklists().list(maxResults=100).execute()
        return results.get("items", [])

    def create_task_list(self, title: str) -> dict:
        service = self._get_service()
        return service.tasklists().insert(body={"title": title}).execute()

    def delete_task_list(self, tasklist_id: str) -> dict:
        service = self._get_service()
        service.tasklists().delete(tasklist=tasklist_id).execute()
        return {"deleted": tasklist_id, "status": "success"}

    def list_tasks(
        self,
        tasklist_id: str,
        show_completed: bool = False,
        show_hidden: bool = False,
    ) -> list[dict]:
        service = self._get_service()
        results = (
            service.tasks()
            .list(
                tasklist=tasklist_id,
                showCompleted=show_completed,
                showHidden=show_hidden,
                maxResults=100,
            )
            .execute()
        )
        return results.get("items", [])

    def get_task(self, tasklist_id: str, task_id: str) -> dict:
        service = self._get_service()
        return service.tasks().get(tasklist=tasklist_id, task=task_id).execute()

    def create_task(
        self,
        tasklist_id: str,
        title: str,
        notes: str = "",
        due: str = "",
        parent: str = "",
    ) -> dict:
        service = self._get_service()
        body: dict = {"title": title}
        if notes:
            body["notes"] = notes
        if due:
            body["due"] = f"{due}T00:00:00.000Z"

        kwargs: dict = {"tasklist": tasklist_id, "body": body}
        if parent:
            kwargs["parent"] = parent

        return service.tasks().insert(**kwargs).execute()

    def update_task(
        self,
        tasklist_id: str,
        task_id: str,
        title: str = "",
        notes: str = "",
        due: str = "",
        status: str = "",
    ) -> dict:
        service = self._get_service()
        task = self.get_task(tasklist_id, task_id)

        if title:
            task["title"] = title
        if notes:
            task["notes"] = notes
        if due:
            task["due"] = f"{due}T00:00:00.000Z"
        if status:
            task["status"] = status

        return (
            service.tasks()
            .update(tasklist=tasklist_id, task=task_id, body=task)
            .execute()
        )

    def delete_task(self, tasklist_id: str, task_id: str) -> None:
        service = self._get_service()
        service.tasks().delete(tasklist=tasklist_id, task=task_id).execute()

    def complete_task(self, tasklist_id: str, task_id: str) -> dict:
        service = self._get_service()
        task = self.get_task(tasklist_id, task_id)
        task["status"] = "completed"
        return (
            service.tasks()
            .update(tasklist=tasklist_id, task=task_id, body=task)
            .execute()
        )

    def clear_completed_tasks(self, tasklist_id: str) -> None:
        service = self._get_service()
        service.tasks().clear(tasklist=tasklist_id).execute()

    def move_task(
        self,
        tasklist_id: str,
        task_id: str,
        parent: str = "",
        previous: str = "",
    ) -> dict:
        service = self._get_service()
        kwargs: dict = {"tasklist": tasklist_id, "task": task_id}
        if parent:
            kwargs["parent"] = parent
        if previous:
            kwargs["previous"] = previous
        return service.tasks().move(**kwargs).execute()

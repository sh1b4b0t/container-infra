import os

from fastmcp import FastMCP

from google_tasks import GoogleTasksClient

mcp = FastMCP("Google Tasks")
client = GoogleTasksClient()


def _err(e: Exception) -> dict:
    return {"error": str(e)}


@mcp.tool
def list_task_lists() -> list | dict:
    """Lista todas as listas de tarefas do Google Tasks."""
    try:
        return client.list_task_lists()
    except Exception as e:
        return _err(e)


@mcp.tool
def create_task_list(title: str) -> dict:
    """Cria uma nova lista de tarefas com o título especificado."""
    try:
        return client.create_task_list(title)
    except Exception as e:
        return _err(e)


@mcp.tool
def delete_task_list(tasklist_id: str) -> dict:
    """Remove uma lista de tarefas pelo ID."""
    try:
        return client.delete_task_list(tasklist_id)
    except Exception as e:
        return _err(e)


@mcp.tool
def list_tasks(
    tasklist_id: str,
    show_completed: bool = False,
    show_hidden: bool = False,
) -> list | dict:
    """
    Lista as tarefas de uma lista específica.

    Args:
        tasklist_id: ID da lista (@default para a lista padrão)
        show_completed: Incluir tarefas concluídas
        show_hidden: Incluir tarefas ocultas
    """
    try:
        return client.list_tasks(tasklist_id, show_completed, show_hidden)
    except Exception as e:
        return _err(e)


@mcp.tool
def get_task(tasklist_id: str, task_id: str) -> dict:
    """Obtém detalhes de uma tarefa específica pelo ID."""
    try:
        return client.get_task(tasklist_id, task_id)
    except Exception as e:
        return _err(e)


@mcp.tool
def create_task(
    tasklist_id: str,
    title: str,
    notes: str = "",
    due: str = "",
    parent: str = "",
) -> dict:
    """
    Cria uma nova tarefa na lista especificada.

    Args:
        tasklist_id: ID da lista de tarefas
        title: Título da tarefa
        notes: Notas/descrição da tarefa
        due: Data de vencimento no formato YYYY-MM-DD
        parent: ID da tarefa pai (para criar subtarefas)
    """
    try:
        return client.create_task(tasklist_id, title, notes, due, parent)
    except Exception as e:
        return _err(e)


@mcp.tool
def update_task(
    tasklist_id: str,
    task_id: str,
    title: str = "",
    notes: str = "",
    due: str = "",
    status: str = "",
) -> dict:
    """
    Atualiza uma tarefa existente.

    Args:
        tasklist_id: ID da lista de tarefas
        task_id: ID da tarefa
        title: Novo título (opcional)
        notes: Novas notas (opcional)
        due: Nova data de vencimento YYYY-MM-DD (opcional)
        status: Novo status — 'needsAction' ou 'completed' (opcional)
    """
    try:
        return client.update_task(tasklist_id, task_id, title, notes, due, status)
    except Exception as e:
        return _err(e)


@mcp.tool
def delete_task(tasklist_id: str, task_id: str) -> dict:
    """Remove uma tarefa pelo ID."""
    try:
        client.delete_task(tasklist_id, task_id)
        return {"deleted": task_id, "status": "success"}
    except Exception as e:
        return _err(e)


@mcp.tool
def complete_task(tasklist_id: str, task_id: str) -> dict:
    """Marca uma tarefa como concluída."""
    try:
        return client.complete_task(tasklist_id, task_id)
    except Exception as e:
        return _err(e)


@mcp.tool
def clear_completed_tasks(tasklist_id: str) -> dict:
    """Remove todas as tarefas concluídas de uma lista."""
    try:
        client.clear_completed_tasks(tasklist_id)
        return {"status": "success", "message": "Tarefas concluídas removidas"}
    except Exception as e:
        return _err(e)


@mcp.tool
def move_task(
    tasklist_id: str,
    task_id: str,
    parent: str = "",
    previous: str = "",
) -> dict:
    """
    Move uma tarefa dentro da lista.

    Args:
        tasklist_id: ID da lista de tarefas
        task_id: ID da tarefa a mover
        parent: ID da nova tarefa pai (para mover como subtarefa)
        previous: ID da tarefa que ficará imediatamente antes desta
    """
    try:
        return client.move_task(tasklist_id, task_id, parent, previous)
    except Exception as e:
        return _err(e)


if __name__ == "__main__":
    port = int(os.environ.get("PORT", 8080))
    mcp.run(transport="http", host="0.0.0.0", port=port)

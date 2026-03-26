from rest_framework.views import exception_handler
from rest_framework.response import Response
from rest_framework import status


def api_exception_handler(exc, context):
    """
    Standardize error shape: {"error": {"message": "...", "details": {...}}}
    """
    response = exception_handler(exc, context)
    if response is None:
        return Response(
            {"error": {"message": "Internal server error", "details": {}}},
            status=status.HTTP_500_INTERNAL_SERVER_ERROR,
        )
    data = response.data
    detail = data.get("detail", None)
    if detail is not None:
        body = {"error": {"message": detail, "details": data if isinstance(data, dict) else {}}}
    else:
        body = {"error": {"message": "Validation error", "details": data}}
    response.data = body
    return response

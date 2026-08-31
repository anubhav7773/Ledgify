from typing import Any, Generic, List, Optional, TypeVar
from pydantic import BaseModel, ConfigDict

T = TypeVar("T")


class ErrorDetail(BaseModel):
    code: str
    message: str
    details: Optional[dict] = None


class ApiResponse(BaseModel, Generic[T]):
    """Standardized API JSON Envelope for all Ledgify endpoints."""
    success: bool = True
    data: Optional[T] = None
    error: Optional[ErrorDetail] = None
    meta: Optional[dict] = None

    model_config = ConfigDict(arbitrary_types_allowed=True)


class PaginationParams(BaseModel):
    page: int = 1
    page_size: int = 50

    @property
    def offset(self) -> int:
        return (self.page - 1) * self.page_size


class PaginatedList(BaseModel, Generic[T]):
    items: List[T]
    total: int
    page: int
    page_size: int
    has_more: bool

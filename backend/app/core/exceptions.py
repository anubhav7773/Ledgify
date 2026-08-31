from typing import Any, Dict, Optional
from fastapi import HTTPException, Request, status
from fastapi.responses import JSONResponse


class LedgifyException(Exception):
    """Base exception for all domain-level Ledgify business logic errors."""
    def __init__(
        self,
        message: str,
        status_code: int = status.HTTP_400_BAD_REQUEST,
        error_code: str = "BUSINESS_RULE_VIOLATION",
        details: Optional[Dict[str, Any]] = None,
    ):
        self.message = message
        self.status_code = status_code
        self.error_code = error_code
        self.details = details or {}
        super().__init__(self.message)


class UnauthorizedException(LedgifyException):
    def __init__(self, message: str = "Authentication credentials were not provided or are invalid."):
        super().__init__(
            message=message,
            status_code=status.HTTP_401_UNAUTHORIZED,
            error_code="UNAUTHORIZED",
        )


class ForbiddenException(LedgifyException):
    def __init__(self, message: str = "You do not have permission to perform this action."):
        super().__init__(
            message=message,
            status_code=status.HTTP_403_FORBIDDEN,
            error_code="FORBIDDEN",
        )


class NotFoundException(LedgifyException):
    def __init__(self, resource: str, resource_id: Optional[str] = None):
        msg = f"{resource} not found." if not resource_id else f"{resource} with ID '{resource_id}' not found."
        super().__init__(
            message=msg,
            status_code=status.HTTP_404_NOT_FOUND,
            error_code="NOT_FOUND",
        )


class DoubleEntryDiscrepancyException(LedgifyException):
    def __init__(self, debit_sum: float, credit_sum: float):
        super().__init__(
            message=f"Voucher entry violates double-entry rule: Total Debit (₹{debit_sum:.2f}) does not match Total Credit (₹{credit_sum:.2f}). Discrepancy: ₹{abs(debit_sum - credit_sum):.2f}",
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            error_code="DOUBLE_ENTRY_IMBALANCE",
            details={"total_debit": debit_sum, "total_credit": credit_sum, "discrepancy": abs(debit_sum - credit_sum)},
        )


class DPDPConsentRequiredException(LedgifyException):
    def __init__(self, purpose_code: str):
        super().__init__(
            message=f"DPDP Act 2023 Violation: Active consent for purpose '{purpose_code}' is required before automated data processing.",
            status_code=status.HTTP_403_FORBIDDEN,
            error_code="DPDP_CONSENT_REQUIRED",
            details={"required_purpose": purpose_code},
        )


async def ledgify_exception_handler(request: Request, exc: LedgifyException) -> JSONResponse:
    """Formats custom Ledgify exceptions into standardized JSON response payloads."""
    return JSONResponse(
        status_code=exc.status_code,
        content={
            "success": False,
            "error": {
                "code": exc.error_code,
                "message": exc.message,
                "details": exc.details,
            },
        },
    )


async def generic_http_exception_handler(request: Request, exc: HTTPException) -> JSONResponse:
    """Formats standard FastAPI HTTPExceptions into standardized JSON response payloads."""
    return JSONResponse(
        status_code=exc.status_code,
        content={
            "success": False,
            "error": {
                "code": "HTTP_ERROR",
                "message": exc.detail if isinstance(exc.detail, str) else str(exc.detail),
                "details": exc.detail if isinstance(exc.detail, dict) else {},
            },
        },
    )

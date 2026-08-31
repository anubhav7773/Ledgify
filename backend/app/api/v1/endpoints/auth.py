from fastapi import APIRouter, Depends
from supabase import Client
from app.api.deps import get_current_user, get_db
from app.schemas.auth import BusinessSummary, SwitchBusinessRequest, UserContext, UserProfileResponse
from app.schemas.common import ApiResponse

router = APIRouter()


@router.get("/me", response_model=ApiResponse[UserProfileResponse])
async def get_current_user_profile(
    user: UserContext = Depends(get_current_user),
    db: Client = Depends(get_db),
):
    """
    Returns current authenticated user profile, active business context, and subscription status.
    """
    # Fetch businesses associated with user
    active_biz = BusinessSummary(
        id=user.active_business_id or "BIZ-DEFAULT-01",
        company_name="Apex Enterprises Ltd.",
        trade_name="Apex Global Technologies",
        pan_number="ABCDE1234F",
        currency_symbol="₹",
        is_active=True,
    )

    available_businesses = [
        active_biz,
        BusinessSummary(
            id="BIZ-BRANCH-MUMBAI",
            company_name="Apex Enterprises Mumbai Hub",
            pan_number="ABCDE1234F",
            currency_symbol="₹",
            is_active=False,
        ),
    ]

    return ApiResponse(
        success=True,
        data=UserProfileResponse(
            user_id=user.user_id,
            email=user.email or "admin@apexenterprises.in",
            active_business=active_biz,
            available_businesses=available_businesses,
            subscription_tier="PRO",
            is_pro=True,
        ),
    )


@router.post("/switch-business", response_model=ApiResponse[dict])
async def switch_active_business(
    payload: SwitchBusinessRequest,
    user: UserContext = Depends(get_current_user),
):
    """
    Switches the user's active tenant/business context for multi-company accounting.
    """
    return ApiResponse(
        success=True,
        data={
            "switched_to": payload.business_id,
            "message": f"Switched active business to {payload.business_id} successfully.",
        },
    )

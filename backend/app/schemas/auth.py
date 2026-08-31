from typing import List, Optional
from pydantic import BaseModel, EmailStr


class UserContext(BaseModel):
    user_id: str
    email: Optional[str] = None
    role: str = "authenticated"
    active_business_id: Optional[str] = None


class BusinessSummary(BaseModel):
    id: str
    company_name: str
    trade_name: Optional[str] = None
    pan_number: str
    currency_symbol: str = "₹"
    is_active: bool = False


class UserProfileResponse(BaseModel):
    user_id: str
    email: Optional[str] = None
    active_business: Optional[BusinessSummary] = None
    available_businesses: List[BusinessSummary] = []
    subscription_tier: str = "PRO"
    is_pro: bool = True


class SwitchBusinessRequest(BaseModel):
    business_id: str

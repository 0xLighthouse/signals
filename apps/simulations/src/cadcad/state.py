from typing import Dict, List, Set, Tuple
from dataclasses import dataclass, field
from datetime import datetime


@dataclass
class Initiative:
    id: str
    title: str
    description: str
    created_at: datetime
    weight: float = 0.0
    last_support_time: datetime = field(default_factory=datetime.now)


@dataclass
class Support:
    amount: float  # Amount of tokens staked
    lock_duration: int  # Duration in epochs
    start_time: datetime
    weight: float = 0.0  # Calculated weight (amount * duration)


@dataclass
class State:
    # Time tracking
    current_epoch: int = 0
    current_time: datetime = field(default_factory=datetime.now)

    # Initiative tracking
    initiatives: Dict[str, Initiative] = field(default_factory=dict)
    accepted_initiatives: Set[str] = field(default_factory=set)
    expired_initiatives: Set[str] = field(default_factory=set)

    # Support tracking
    supporters: Dict[Tuple[str, str], Support] = field(default_factory=dict)  # (user_id, initiative_id) -> Support

    # System parameters
    acceptance_threshold: float = 1000.0  # Weight threshold for initiative acceptance
    inactivity_period: int = 10  # Number of epochs before initiative expires
    decay_multiplier: float = 0.95  # Multiplier for exponential decay

    def get_initiative_weight(self, initiative_id: str) -> float:
        """Calculate total weight for an initiative from all supporters."""
        return sum(support.weight for (_, init_id), support in self.supporters.items() if init_id == initiative_id)

    def update_initiative_weights(self) -> None:
        """Update weights for all initiatives."""
        for initiative_id in self.initiatives:
            self.initiatives[initiative_id].weight = self.get_initiative_weight(initiative_id)

    def get_user_support(self, user_id: str) -> Dict[str, Support]:
        """Get all support entries for a user."""
        return {initiative_id: support for (uid, initiative_id), support in self.supporters.items() if uid == user_id}

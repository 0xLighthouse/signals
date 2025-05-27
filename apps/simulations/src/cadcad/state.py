from dataclasses import dataclass, field
from datetime import datetime
from typing import Dict, Set, Any, Tuple, List, Optional
from supply.allocate import allocate_tokens


@dataclass
class Initiative:
    id: str
    title: str
    description: str
    created_at: datetime
    weight: float = 0.0
    last_support_time: datetime = field(default_factory=datetime.now)
    last_support_epoch: int = 0


@dataclass
class Support:
    user_id: str
    initiative_id: str
    amount: float
    lock_duration_epochs: int
    start_epoch: int
    initial_weight: float = field(init=False)
    current_weight: float = field(init=False)
    expiry_epoch: int = field(init=False)

    def __post_init__(self):
        self.initial_weight = self.amount * self.lock_duration_epochs
        self.current_weight = self.initial_weight
        self.expiry_epoch = self.start_epoch + self.lock_duration_epochs

    def decay(self, decay_multiplier: float, current_epoch: int) -> None:
        """Apply decay to the current weight if the lock is active and not expired."""
        if self.start_epoch < current_epoch < self.expiry_epoch:
            self.current_weight *= decay_multiplier
            self.current_weight = max(0, self.current_weight)


@dataclass
class State:
    def __init__(self, **kwargs):
        self.current_epoch: int = kwargs.get("current_epoch", 0)
        self.current_time: datetime = kwargs.get("current_time", datetime.now())
        self.initiatives: Dict[str, Initiative] = kwargs.get("initiatives", {})
        self.accepted_initiatives: Set[str] = kwargs.get("accepted_initiatives", set())
        self.expired_initiatives: Set[str] = kwargs.get("expired_initiatives", set())
        self.supporters: Dict[Tuple[str, str], Support] = kwargs.get("supporters", {})
        self.acceptance_threshold: float = kwargs.get("acceptance_threshold", 1000.0)
        self.inactivity_period: int = kwargs.get("inactivity_period", 10)
        self.decay_multiplier: float = kwargs.get("decay_multiplier", 0.95)
        self.total_supply: int = kwargs.get("total_supply", 0)
        self.circulating_supply: int = kwargs.get("circulating_supply", 0)
        self.balances: Dict[str, int] = kwargs.get("balances", {})

        # Add reward tracking
        self.reward_earnings: Dict[str, float] = kwargs.get(
            "reward_earnings", {}
        )  # Total rewards earned per user
        self.reward_history: List[Dict[str, Any]] = kwargs.get(
            "reward_history", []
        )  # Detailed reward history

    def __dict__(self):
        """Convert state to dictionary for cadCAD."""
        initiatives_copy = (
            {k: v.__dict__ for k, v in self.initiatives.items()} if self.initiatives else {}
        )
        supporters_copy = (
            {k: v.__dict__ for k, v in self.supporters.items()} if self.supporters else {}
        )
        balances_copy = dict(self.balances)
        accepted_copy = set(self.accepted_initiatives)
        expired_copy = set(self.expired_initiatives)
        reward_earnings_copy = dict(self.reward_earnings)
        reward_history_copy = list(self.reward_history)

        return {
            "current_epoch": self.current_epoch,
            "current_time": self.current_time.isoformat()
            if isinstance(self.current_time, datetime)
            else self.current_time,
            "initiatives": initiatives_copy,
            "accepted_initiatives": accepted_copy,
            "expired_initiatives": expired_copy,
            "supporters": supporters_copy,
            "acceptance_threshold": self.acceptance_threshold,
            "inactivity_period": self.inactivity_period,
            "decay_multiplier": self.decay_multiplier,
            "total_supply": self.total_supply,
            "circulating_supply": self.circulating_supply,
            "balances": balances_copy,
            "reward_earnings": reward_earnings_copy,
            "reward_history": reward_history_copy,
        }

    def get_initiative_weight(self, initiative_id: str) -> float:
        """Calculate total current weight for an initiative from all its supporters."""
        return sum(
            support.current_weight
            for (uid, init_id), support in self.supporters.items()
            if init_id == initiative_id
        )

    def update_initiative_weights(self) -> None:
        """Update current weights for all initiatives based on their support."""
        for initiative_id, initiative in self.initiatives.items():
            initiative.weight = self.get_initiative_weight(initiative_id)

    def get_user_support(self, user_id: str) -> Dict[str, Support]:
        """Get all support entries for a user."""
        return {
            initiative_id: support
            for (uid, initiative_id), support in self.supporters.items()
            if uid == user_id
        }

    def record_reward(
        self,
        user_id: str,
        amount: float,
        initiative_id: str,
        initiative_weight: float,
        support_amount: float,
        lock_duration: int,
    ) -> None:
        """Record a reward payment to a user with detailed information."""
        # Update total earnings
        self.reward_earnings[user_id] = self.reward_earnings.get(user_id, 0) + amount

        # Record detailed history
        reward_entry = {
            "epoch": self.current_epoch,
            "timestamp": self.current_time.isoformat(),
            "user_id": user_id,
            "initiative_id": initiative_id,
            "reward_amount": amount,
            "support_amount": support_amount,
            "lock_duration": lock_duration,
            "initiative_weight": initiative_weight,
            "weight_percentage": initiative_weight / self.acceptance_threshold,
            "user_balance_before": self.balances.get(user_id, 0) - amount,  # Balance before reward
            "user_balance_after": self.balances.get(user_id, 0),  # Balance after reward
        }
        self.reward_history.append(reward_entry)


def generate_initial_state(
    num_users=10,
    total_supply=100_000,
    circulating_supply=100_000,
    distribution: Optional[List[int]] = None,
    randomize: bool = True,
) -> Dict:
    # Generate user ids
    user_ids = [f"0x{i:02x}" for i in range(num_users)]

    # Allocate tokens to users
    balance_by_user_id = allocate_tokens(
        user_ids, total_supply, circulating_supply, distribution, randomize
    )

    current_time = datetime.now()

    initial_state_obj = State(
        current_epoch=0,
        current_time=current_time,
        initiatives={},
        accepted_initiatives=set(),
        expired_initiatives=set(),
        supporters={},
        balances=balance_by_user_id,
        total_supply=total_supply,
        circulating_supply=circulating_supply,
        # These will use defaults from State class __init__ or be overridden by system_params later in SUFs if needed.
        # No need to pass them here from a non-existent kwargs in generate_initial_state
        # acceptance_threshold=3000.0, # Default from State class is 1000.0
        # inactivity_period=10,      # Default from State class
        # decay_multiplier=0.95,     # Default from State class
    )

    return initial_state_obj.__dict__()

"""
RMS Enterprise Unified Pricing Scheduler Service
Lightweight, non-blocking background worker for scheduled price activations.
Runs bounded within FastAPI application lifespan with deterministic startup catchup,
safe shutdown cancellation, and zero unmanaged global threads.
"""
import asyncio
import logging
from datetime import datetime
from typing import Optional, Callable, List, Dict, Any
from .pricing_service import PricingService

logger = logging.getLogger("rms.pricing_scheduler")

class PricingScheduler:
    def __init__(
        self,
        interval_seconds: float = 60.0,
        clock: Optional[Callable[[], datetime]] = None,
    ):
        self.interval_seconds = interval_seconds
        self.clock = clock
        self._task: Optional[asyncio.Task] = None
        self._running: bool = False

    def is_running(self) -> bool:
        return self._running and self._task is not None and not self._task.done()

    def start(self) -> None:
        if self._running:
            return
        self._running = True
        self._task = asyncio.create_task(self._run_loop(), name="rms_pricing_scheduler_task")
        logger.info(f"Pricing scheduler started with interval {self.interval_seconds}s")

    async def stop(self) -> None:
        self._running = False
        if self._task and not self._task.done():
            self._task.cancel()
            try:
                await self._task
            except asyncio.CancelledError:
                pass
            except Exception as e:
                logger.warning(f"Error awaiting pricing scheduler task shutdown: {e}")
        self._task = None
        logger.info("Pricing scheduler stopped cleanly")

    async def _run_loop(self) -> None:
        while self._running:
            try:
                activated = PricingService.activate_due_prices(clock=self.clock)
                if activated:
                    logger.info(f"Activated {len(activated)} due prices: {activated}")
            except Exception as e:
                logger.error(f"Error in pricing scheduler activation pass: {e}")
            try:
                await asyncio.sleep(self.interval_seconds)
            except asyncio.CancelledError:
                break

    @staticmethod
    def run_once(clock: Optional[Callable[[], datetime]] = None) -> List[Dict[str, Any]]:
        return PricingService.activate_due_prices(clock=clock)

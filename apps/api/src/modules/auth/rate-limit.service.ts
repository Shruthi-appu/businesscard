import { Inject, Injectable } from "@nestjs/common";

import { ApiException } from "../../common/api.exception";
import { RedisService } from "../../redis/redis.service";

@Injectable()
export class RateLimitService {
  constructor(@Inject(RedisService) private readonly redis: RedisService) {}

  async consume(
    bucket: string,
    max: number,
    windowSeconds: number,
    unavailable = "Authentication is temporarily unavailable",
  ): Promise<void> {
    let count: number;
    try {
      count = await this.redis.incr(`rl:${bucket}`, windowSeconds);
    } catch (error) {
      if (error instanceof ApiException) throw error;
      throw new ApiException(503, "service_unavailable", unavailable);
    }
    if (count > max) {
      throw new ApiException(429, "rate_limited", "Too many attempts");
    }
  }
}

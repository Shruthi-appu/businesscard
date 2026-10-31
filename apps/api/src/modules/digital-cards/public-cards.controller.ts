import { Controller, Get, Inject, Param } from "@nestjs/common";
import { ApiOperation, ApiTags } from "@nestjs/swagger";

import { DigitalCardsService } from "./digital-cards.service";

@ApiTags("public")
@Controller("public/cards")
export class PublicCardsController {
  constructor(@Inject(DigitalCardsService) private readonly cards: DigitalCardsService) {}

  @Get(":slug")
  @ApiOperation({ summary: "Read a published card. Private fields are omitted." })
  getOne(@Param("slug") slug: string) {
    return this.cards.publicBySlug(slug.toLowerCase());
  }
}

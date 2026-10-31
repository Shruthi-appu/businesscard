import {
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  Inject,
  Param,
  Patch,
  Post,
  Req,
  UseGuards,
} from "@nestjs/common";
import { ApiBearerAuth, ApiOperation, ApiTags } from "@nestjs/swagger";
import { z } from "zod";

import { AccessAuthGuard } from "../../common/access-auth.guard";
import { CurrentUser } from "../../common/current-user";
import type { AccessPrincipal, RequestWithContext } from "../../common/request-context";
import { ZodValidationPipe } from "../../common/zod.pipe";
import { CardsService } from "./cards.service";

const favouriteSchema = z.object({ isFavourite: z.boolean() });
const tagSchema = z.object({ name: z.string().trim().min(1).max(40) });
const noteSchema = z.object({ body: z.string().trim().min(1).max(2000) });
const reminderSchema = z.object({
  remindAt: z.string().min(1),
  note: z.string().trim().max(500).optional(),
});
const reminderPatchSchema = z.object({
  status: z.enum(["scheduled", "done", "cancelled"]),
});

@ApiTags("wallet")
@ApiBearerAuth()
@UseGuards(AccessAuthGuard)
@Controller("wallet/entries")
export class WalletController {
  constructor(@Inject(CardsService) private readonly cards: CardsService) {}

  @Post(":id/favourite")
  @HttpCode(200)
  @ApiOperation({ summary: "Mark or clear a favourite on the caller's wallet entry." })
  favourite(
    @CurrentUser() user: AccessPrincipal,
    @Param("id") id: string,
    @Body(new ZodValidationPipe(favouriteSchema)) body: { isFavourite: boolean },
  ) {
    return this.cards.setFavourite(user.id, id, body.isFavourite);
  }

  @Post(":id/tags")
  @HttpCode(201)
  @ApiOperation({ summary: "Attach a tag to the caller's wallet entry." })
  addTag(
    @CurrentUser() user: AccessPrincipal,
    @Param("id") id: string,
    @Body(new ZodValidationPipe(tagSchema)) body: { name: string },
  ) {
    return this.cards.addTag(user.id, id, body.name);
  }

  @Delete(":id/tags/:tagId")
  @HttpCode(204)
  @ApiOperation({ summary: "Remove a tag from the caller's wallet entry." })
  async removeTag(
    @CurrentUser() user: AccessPrincipal,
    @Param("id") id: string,
    @Param("tagId") tagId: string,
  ): Promise<void> {
    await this.cards.removeTag(user.id, id, tagId);
  }

  @Post(":id/notes")
  @HttpCode(201)
  @ApiOperation({ summary: "Add a private note on the caller's wallet entry." })
  addNote(
    @CurrentUser() user: AccessPrincipal,
    @Param("id") id: string,
    @Body(new ZodValidationPipe(noteSchema)) body: { body: string },
  ) {
    return this.cards.addNote(user.id, id, body.body);
  }

  @Post(":id/reminders")
  @HttpCode(201)
  @ApiOperation({ summary: "Schedule a reminder on the caller's wallet entry." })
  addReminder(
    @CurrentUser() user: AccessPrincipal,
    @Param("id") id: string,
    @Body(new ZodValidationPipe(reminderSchema)) body: { remindAt: string; note?: string },
  ) {
    return this.cards.addReminder(user.id, id, body.remindAt, body.note);
  }

  @Patch(":id/reminders/:reminderId")
  @ApiOperation({ summary: "Update a reminder status." })
  patchReminder(
    @CurrentUser() user: AccessPrincipal,
    @Param("id") id: string,
    @Param("reminderId") reminderId: string,
    @Body(new ZodValidationPipe(reminderPatchSchema))
    body: { status: "scheduled" | "done" | "cancelled" },
  ) {
    return this.cards.patchReminder(user.id, id, reminderId, body.status);
  }

  @Get(":id/history")
  @ApiOperation({ summary: "History events for the caller's wallet entry. No contact values." })
  history(@CurrentUser() user: AccessPrincipal, @Param("id") id: string) {
    return this.cards.history(user.id, id);
  }

  @Delete(":id")
  @HttpCode(204)
  @ApiOperation({ summary: "Soft-delete the caller's wallet entry." })
  async remove(
    @CurrentUser() user: AccessPrincipal,
    @Param("id") id: string,
    @Req() req: RequestWithContext,
  ): Promise<void> {
    await this.cards.softDelete(user.id, id, req.requestId ?? "unknown");
  }
}

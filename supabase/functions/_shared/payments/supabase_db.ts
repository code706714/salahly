import type { SupabaseClient } from "npm:@supabase/supabase-js@2";
import type {
  ApplyResult,
  CreatedOrder,
  CreateRequest,
  CustomerSession,
  PaymentsDb,
  RefundSession,
  UnsettledOrder,
} from "./service.ts";
import { OrderRefusedError } from "./service.ts";
import type { NormalizedPayment } from "./types.ts";

/** Database refusals the app can act on, by the name the database raises. */
const refusals: Record<string, number> = {
  not_signed_in: 401,
  account_suspended: 403,
  pack_not_found: 404,
  not_found: 404,
  escrow_not_found: 404,
  price_changed: 409,
  escrow_unavailable: 409,
  already_secured: 409,
  not_refund_due: 409,
  rate_limited: 429,
  admin_required: 403,
  recent_login_required: 403,
};

function refusal(error: { message: string }): Error {
  const status = refusals[error.message];
  return status === undefined
    ? new Error("database_error")
    : new OrderRefusedError(error.message, status);
}

/** The service role's calls: only the Edge Functions make them. */
export class SupabasePaymentsDb implements PaymentsDb {
  constructor(private readonly admin: SupabaseClient) {}

  async applyEvent(
    payment: NormalizedPayment,
    source: "webhook" | "inquiry",
  ): Promise<ApplyResult> {
    const { data, error } = await this.admin.rpc("payments_apply_event", {
      p_provider: payment.provider,
      p_event_key: payment.eventKey,
      p_source: source,
      p_provider_order_id: payment.providerOrderId,
      p_merchant_ref: payment.merchantRef,
      p_provider_txn_id: payment.providerTxnId,
      p_status: payment.status,
      p_amount_piastres: payment.amountPiastres,
      p_currency: payment.currency,
      p_payment_method: payment.paymentMethod,
    });
    if (error) throw new Error("apply_failed");
    return data as ApplyResult;
  }

  async unsettled(limit: number): Promise<UnsettledOrder[]> {
    const { data, error } = await this.admin.rpc("payments_unsettled", {
      p_limit: limit,
    });
    if (error) throw new Error("unsettled_failed");
    return (data ?? []) as UnsettledOrder[];
  }

  async attachProvider(
    orderId: string,
    provider: string,
    providerOrderId: string,
  ): Promise<void> {
    const { error } = await this.admin.rpc("payments_attach_provider", {
      p_order_id: orderId,
      p_provider: provider,
      p_provider_order_id: providerOrderId,
    });
    if (error) throw new Error("attach_failed");
  }

  async recordRefund(
    orderId: string,
    reference: string,
    adminId: string,
  ): Promise<void> {
    const { error } = await this.admin.rpc("payments_record_refund", {
      p_order_id: orderId,
      p_reference: reference,
      p_admin_id: adminId,
    });
    if (error) throw new Error("refund_record_failed");
  }
}

/** The signed-in person's session (their JWT), for creating their own order. */
export class SupabaseCustomerSession implements CustomerSession {
  constructor(private readonly user: SupabaseClient) {}

  async createOrder(request: CreateRequest): Promise<CreatedOrder> {
    const { data, error } = request.purpose === "credit_pack"
      ? await this.user.rpc("create_credit_pack_payment", {
        p_pack_id: request.packId,
        p_expected_price_piastres: request.expectedPricePiastres,
      })
      : await this.user.rpc("create_escrow_payment", {
        p_request_id: request.requestId,
      });
    if (error) throw refusal(error);
    const row = data as {
      order_id: string;
      amount_piastres: number;
      currency: string;
      description: string;
    };
    return {
      orderId: row.order_id,
      amountPiastres: Number(row.amount_piastres),
      currency: row.currency,
      description: row.description,
    };
  }

  async billing(): Promise<{ name: string | null; phone: string | null }> {
    const { data } = await this.user.auth.getUser();
    const { data: profile } = await this.user.from("profiles")
      .select("full_name")
      .eq("id", data.user?.id ?? "")
      .maybeSingle();
    return {
      name: (profile as { full_name: string | null } | null)?.full_name ?? null,
      phone: data.user?.phone ? `+${data.user.phone.replace(/^\+/, "")}` : null,
    };
  }
}

/** The signed-in admin's session, for the refund they ask for. */
export class SupabaseRefundSession implements RefundSession {
  constructor(
    private readonly user: SupabaseClient,
    readonly adminId: string,
  ) {}

  async target(escrowId: string) {
    const { data, error } = await this.user.rpc("admin_payment_refund_target", {
      p_escrow_id: escrowId,
    });
    if (error) throw refusal(error);
    const row = data as {
      order_id: string;
      provider: string;
      provider_txn_id: string;
      amount_piastres: number;
    };
    return {
      orderId: row.order_id,
      provider: row.provider,
      providerTxnId: row.provider_txn_id,
      amountPiastres: Number(row.amount_piastres),
    };
  }
}

// The Arabic text of a push, built from the kind of notification. It
// mirrors what the app shows in its notification list (lib/l10n/app_ar.arb)
// and carries only what the text needs: never a phone number, an address
// or the other person's full name.

/** One queued push as `push_claim` hands it out. */
export interface PushItem {
  id: number;
  kind: string;
  role: "consumer" | "technician";
  request_id: string | null;
  /** The technician's first name, for a consumer's push. */
  technician_name: string | null;
  /** The consumer's honorific; picks the gender of the copy. */
  honorific: "ms" | "mr" | null;
  tokens: string[];
}

export interface PushMessage {
  title: string;
  body?: string;
  /** What the app needs to open the right screen. All strings (FCM). */
  data: Record<string, string>;
}

const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;

type Text = { title: string; body?: string };

function textOf(item: PushItem): Text | null {
  const name = item.technician_name?.trim() || "الفني";
  const she = item.honorific === "ms";
  switch (item.kind) {
    case "offer_received":
      return {
        title: "وصلك عرض جديد",
        body: she ? "افتحي الطلب وشوفي العرض." : "افتح الطلب وشوف العرض.",
      };
    case "technician_arriving":
      return { title: `${name} قرّب يوصلك`, body: "خلّي تليفونك معاك." };
    case "job_confirmed":
      return { title: `${name} أكّد معادك` };
    case "job_started":
      return { title: `${name} بدأ الشغل` };
    case "job_finished":
      return {
        title: `${name} خلّص الشغلانة`,
        body: "تقييمك بيساعد جيرانك يختاروا صح",
      };
    case "price_change":
      return {
        title: `${name} عايز موافقتك على سعر جديد`,
        body: she ? "مش هيكمّل غير لما توافقي." : "مش هيكمّل غير لما توافق.",
      };
    case "request_cancelled_by_technician":
      return {
        title: `${name} ألغى طلبك`,
        body: she
          ? "رجّعنالك الطلب المجاني. اطلبي فني تاني."
          : "رجّعنالك الطلب المجاني. اطلب فني تاني.",
      };
    case "request_expired":
      return {
        title: "طلبك خلص من غير ما يوصلك عرض",
        body: she
          ? "رجّعنالك الطلب المجاني. اطلبي تاني بمعاد تاني."
          : "رجّعنالك الطلب المجاني. اطلب تاني بمعاد تاني.",
      };
    case "new_request":
      return { title: "طلب جديد", body: "افتح الطلب وابعت عرضك." };
    case "urgent_request":
      return {
        title: "طلب مستعجل",
        body: "عميل محتاج فني دلوقتي. افتح وابعت عرضك.",
      };
    case "chat_message":
      return { title: "رسالة جديدة", body: "افتح المحادثة وردّ." };
    case "incoming_call":
      return { title: "مكالمة جاية", body: "افتح صلحلي عشان تردّ." };
    case "escrow_held":
      return item.role === "technician"
        ? {
          title: "العميل أمّن فلوس الشغلانة",
          body: "الفلوس عند صلحلي وهتوصلك بعد ما العميل يأكّد الشغل.",
        }
        : {
          title: "فلوسك اتأمّنت",
          body: "الفلوس معانا ومش هتوصل للفني غير لما تأكّد الشغل.",
        };
    case "escrow_rejected":
      return {
        title: "ما لقيناش التحويل",
        body: she
          ? "افتحي الطلب وشوفي السبب وابعتي التحويل تاني."
          : "افتح الطلب وشوف السبب وابعت التحويل تاني.",
      };
    case "escrow_released":
      return {
        title: "العميل أكّد الشغل",
        body: "هنحوّل لك الفلوس على حساب الاستلام قريب.",
      };
    case "escrow_paid_out":
      return {
        title: "الفلوس اتحوّلت لك",
        body: "راجع حسابك. لو ماوصلتش كلمنا.",
      };
    case "escrow_disputed":
      return {
        title: "العميل اعترض على الشغل",
        body: "الفلوس معانا لحد ما نراجع الموضوع ونكلمك.",
      };
    case "escrow_refunded":
      return {
        title: "رجّعنا فلوسك",
        body: she
          ? "راجعي حسابك. لو ماوصلتش كلمينا."
          : "راجع حسابك. لو ماوصلتش كلمنا.",
      };
    case "offer_picked":
      return { title: "عرضك اتختار", body: "افتح الشغلانة وشوف التفاصيل." };
    case "request_cancelled_by_consumer":
      return {
        title: "الطلب اتلغى",
        body: "لو كانت شغلانة اتخصمت من رصيدك، رجعتلك.",
      };
    case "verification_approved":
      return { title: "حسابك اتوثّق" };
    case "verification_rejected":
      return {
        title: "حسابك ماتوثّقش",
        body: "الصور اللي بعتّها مش واضحة أو ناقصة. كلمنا عشان نساعدك.",
      };
    case "topup_approved":
      return { title: "التحويل اتأكد" };
    case "topup_rejected":
      return {
        title: "التحويل ماتقبلش",
        body: she
          ? "راجعي الصورة والرقم وجرّبي تاني."
          : "راجع الصورة والرقم وجرّب تاني.",
      };
    default:
      return null;
  }
}

/** The push for [item], or null for a kind this version doesn't know. */
export function buildMessage(item: PushItem): PushMessage | null {
  const text = textOf(item);
  if (text === null) {
    return null;
  }
  const data: Record<string, string> = { kind: item.kind, role: item.role };
  if (item.request_id !== null && uuid.test(item.request_id)) {
    data.request_id = item.request_id;
  }
  return { ...text, data };
}

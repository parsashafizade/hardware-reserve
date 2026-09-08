import { accountEn, accountFa } from "./translations/account";
import { adminEn, adminFa } from "./translations/admin";
import { authEn, authFa } from "./translations/auth";
import { catalogEn, catalogFa } from "./translations/catalog";
import { commonEn, commonFa } from "./translations/common";
import { marketingEn, marketingFa } from "./translations/marketing";
import { supportEn, supportFa } from "./translations/support";
import { lifecycleEn, lifecycleFa } from "./translations/lifecycle";
import { dashboardEn, dashboardFa } from "./translations/dashboard";

export const resources = {
  fa: {
    translation: {
      ...commonFa,
      ...authFa,
      ...marketingFa,
      ...catalogFa,
      ...accountFa,
      ...adminFa,
      ...supportFa,
      ...lifecycleFa,
      ...dashboardFa,
    },
  },
  en: {
    translation: {
      ...commonEn,
      ...authEn,
      ...marketingEn,
      ...catalogEn,
      ...accountEn,
      ...adminEn,
      ...supportEn,
      ...lifecycleEn,
      ...dashboardEn,
    },
  },
} as const;

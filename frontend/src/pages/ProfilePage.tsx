import { useEffect, useMemo, useState } from "react";
import Cropper, { type Area } from "react-easy-crop";
import { useTranslation } from "react-i18next";
import { useSearchParams } from "react-router-dom";
import {
  AlertCircle,
  BadgeCheck,
  CalendarDays,
  Camera,
  CheckCircle2,
  ImagePlus,
  LoaderCircle,
  RotateCcw,
  Save,
  ShieldCheck,
  SlidersHorizontal,
  UserRound,
  X,
} from "lucide-react";
import { authApi } from "../api/authApi";
import { API_BASE_URL } from "../api/config";
import { AccountNavigation } from "../components/account/AccountNavigation";
import { EmailChangePanel } from "../components/account/EmailChangePanel";
import { PageHeader } from "../components/ui/PageHeader";
import { StatusBadge } from "../components/ui/StatusBadge";
import { ProfileSupportHistory } from "../components/support/ProfileSupportHistory";
import type { Profile } from "../types/api";
import { getCroppedImageBlob } from "../utils/cropImage";
import { getApiErrorMessage } from "../utils/errors";
import { formatDateTime } from "../utils/format";
import { useLocale } from "../i18n/useLocale";
import "react-easy-crop/react-easy-crop.css";

const MAX_PROFILE_IMAGE_BYTES = 2 * 1024 * 1024;
const SUPPORTED_IMAGE_TYPES = new Set(["image/jpeg", "image/png", "image/webp"]);

function toAbsoluteImagePath(path: string): string {
  if (!path) {
    return "";
  }

  if (path.startsWith("http://") || path.startsWith("https://")) {
    return path;
  }

  return `${API_BASE_URL}${path}`;
}

function getInitials(fullName: string): string {
  const initials = fullName
    .trim()
    .split(/\s+/)
    .slice(0, 2)
    .map((part) => part[0]?.toUpperCase())
    .join("");

  return initials || "HR";
}

function ProfileSkeleton({ label }: { label: string }) {
  return (
    <div className="grid gap-5 lg:grid-cols-[0.78fr_1.22fr]" role="status" aria-label={label}>
      <div className="skeleton min-h-[28rem] rounded-panel" />
      <div className="rounded-card border border-border-subtle bg-white p-6 shadow-card">
        <div className="skeleton h-6 w-48" />
        <div className="mt-8 space-y-5">
          <div className="space-y-2"><div className="skeleton h-4 w-24" /><div className="skeleton h-11" /></div>
          <div className="space-y-2"><div className="skeleton h-4 w-16" /><div className="skeleton h-11" /></div>
          <div className="skeleton h-11 w-40" />
        </div>
      </div>
    </div>
  );
}

export function ProfilePage() {
  const { t } = useTranslation();
  const { formatNumber } = useLocale();
  const [searchParams] = useSearchParams();
  const [profile, setProfile] = useState<Profile | null>(null);
  const [fullName, setFullName] = useState("");
  const [message, setMessage] = useState("");
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [requestVersion, setRequestVersion] = useState(0);

  const [cropSource, setCropSource] = useState<string | null>(null);
  const [crop, setCrop] = useState({ x: 0, y: 0 });
  const [zoom, setZoom] = useState(1);
  const [cropPixels, setCropPixels] = useState<Area | null>(null);
  const [uploadingImage, setUploadingImage] = useState(false);

  const profileImageUrl = useMemo(
    () => (profile?.profileImagePath ? toAbsoluteImagePath(profile.profileImagePath) : ""),
    [profile?.profileImagePath],
  );
  const formChanged = Boolean(
    profile && fullName.trim() !== profile.fullName,
  );

  useEffect(() => {
    let cancelled = false;

    const loadProfile = async () => {
      setLoading(true);
      setError("");
      try {
        const response = await authApi.getProfile();
        if (!cancelled) {
          setProfile(response);
          setFullName(response.fullName);
        }
      } catch (loadError) {
        if (!cancelled) {
          setProfile(null);
          setError(getApiErrorMessage(loadError, t("profile.loadError")));
        }
      } finally {
        if (!cancelled) {
          setLoading(false);
        }
      }
    };

    void loadProfile();
    return () => {
      cancelled = true;
    };
  }, [requestVersion, t]);

  const onSubmit = async (event: React.FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    setError("");
    setMessage("");
    setSaving(true);

    try {
      const updated = await authApi.updateProfile({
        fullName: fullName.trim(),
      });

      setProfile(updated);
      setFullName(updated.fullName);
      setMessage(t("profile.updateSuccess"));
    } catch (updateError) {
      setError(getApiErrorMessage(updateError, t("profile.updateError")));
    } finally {
      setSaving(false);
    }
  };

  const onSelectImage = (event: React.ChangeEvent<HTMLInputElement>) => {
    const selected = event.target.files?.[0];
    event.target.value = "";
    if (!selected) {
      return;
    }

    setMessage("");
    setError("");

    if (!SUPPORTED_IMAGE_TYPES.has(selected.type)) {
      setError(t("profile.imageTypeError"));
      return;
    }

    if (selected.size > MAX_PROFILE_IMAGE_BYTES) {
      setError(t("profile.imageSizeError"));
      return;
    }

    const reader = new FileReader();
    reader.onload = () => {
      setCropSource(String(reader.result));
      setCrop({ x: 0, y: 0 });
      setZoom(1);
      setCropPixels(null);
    };
    reader.onerror = () => setError(t("profile.imageReadError"));
    reader.readAsDataURL(selected);
  };

  const uploadCroppedImage = async () => {
    if (!cropSource || !cropPixels) {
      setError(t("profile.cropRequired"));
      return;
    }

    setUploadingImage(true);
    setError("");
    setMessage("");

    try {
      const blob = await getCroppedImageBlob(cropSource, cropPixels);
      if (blob.size > MAX_PROFILE_IMAGE_BYTES) {
        setError(t("profile.croppedSizeError"));
        return;
      }

      const updated = await authApi.uploadProfileImage(blob);
      setProfile(updated);
      setCropSource(null);
      setMessage(t("profile.imageSuccess"));
    } catch (uploadError) {
      setError(getApiErrorMessage(uploadError, t("profile.imageUploadError")));
    } finally {
      setUploadingImage(false);
    }
  };

  return (
    <div className="page-stack">
      <AccountNavigation />

      <PageHeader
        eyebrow={t("profile.eyebrow")}
        title={t("profile.title")}
        description={t("profile.description")}
        icon={UserRound}
      />

      {!loading && profile && (message || error) && (
        <div aria-live="polite">
          {message && (
            <div className="alert-success flex items-start gap-2.5" role="status">
              <CheckCircle2 aria-hidden="true" className="mt-0.5 shrink-0" size={17} />
              <p>{message}</p>
            </div>
          )}
          {error && (
            <div className="alert-error flex items-start gap-2.5" role="alert">
              <AlertCircle aria-hidden="true" className="mt-0.5 shrink-0" size={17} />
              <p>{error}</p>
            </div>
          )}
        </div>
      )}

      {loading ? (
        <ProfileSkeleton label={t("profile.loading")} />
      ) : !profile ? (
        <div className="state-panel" role="alert">
          <span className="icon-tile-neutral"><AlertCircle aria-hidden="true" size={21} /></span>
          <h2 className="mt-4 card-title">{t("profile.unavailableTitle")}</h2>
          <p className="mt-2 max-w-md body-copy">{error || t("profile.unavailableCopy")}</p>
          <button type="button" className="btn-primary mt-5" onClick={() => setRequestVersion((version) => version + 1)}>
            <RotateCcw aria-hidden="true" size={16} />
            {t("actions.retry")}
          </button>
        </div>
      ) : (
        <div className="content-swap-enter grid items-start gap-5 lg:grid-cols-[0.78fr_1.22fr]">
          <aside className="card-inverse p-6 sm:p-7" aria-label={t("profile.identityAria")}>
            <div aria-hidden="true" className="absolute -right-16 -top-16 size-52 rounded-full bg-brand-400/15 blur-3xl" />
            <div aria-hidden="true" className="absolute -bottom-20 -left-16 size-56 rounded-full bg-blue-400/10 blur-3xl" />
            <div className="relative">
              <div className="flex items-center justify-between gap-3">
                <p className="text-xs font-bold uppercase tracking-[0.16em] text-brand-200">{t("profile.identity")}</p>
                <StatusBadge tone="success" className="border-white/10 bg-white/10 text-emerald-200" showDot>
                  {profile.role.toLowerCase() === "admin" ? t("admin.common.roleAdmin") : t("admin.common.roleUser")}
                </StatusBadge>
              </div>

              <div className="mt-6 flex flex-col items-center text-center sm:mt-8">
                <div className="relative">
                  {profileImageUrl ? (
                    <img
                      src={profileImageUrl}
                      alt={t("profile.profileAlt", { name: profile.fullName })}
                      width={128}
                      height={128}
                      decoding="async"
                      className="size-32 rounded-[2rem] border-4 border-white/10 object-cover shadow-floating"
                    />
                  ) : (
                    <div className="flex size-32 items-center justify-center rounded-[2rem] border border-white/15 bg-gradient-to-br from-brand-400/30 to-blue-400/10 text-3xl font-semibold text-white shadow-floating">
                      {getInitials(profile.fullName)}
                    </div>
                  )}
                  <span className="absolute -bottom-2 -end-2 inline-flex size-10 items-center justify-center rounded-xl border-4 border-surface-inverse bg-brand-500 text-white shadow-control">
                    <BadgeCheck aria-hidden="true" size={18} />
                  </span>
                </div>

                <h2 dir="auto" className="mt-5 text-2xl font-semibold tracking-[-0.035em] text-white">{profile.fullName}</h2>
                <p dir="ltr" className="technical-value mt-2 break-all text-sm text-ink-300">{profile.email}</p>

                <label className="btn-outline-light mt-5 cursor-pointer">
                  <ImagePlus aria-hidden="true" size={17} />
                  {t("profile.chooseImage")}
                  <input
                    type="file"
                    accept="image/png,image/jpeg,image/webp"
                    className="sr-only"
                    onChange={onSelectImage}
                    disabled={uploadingImage}
                  />
                </label>
                <p className="mt-3 text-xs leading-5 text-ink-300">{t("profile.imageRequirements")}</p>
              </div>

              <dl className="mt-6 grid grid-cols-2 gap-3 border-t border-white/10 pt-5 lg:grid-cols-1 xl:grid-cols-2">
                <div className="rounded-control border border-white/10 bg-white/[0.055] p-3.5">
                  <dt className="inline-flex items-center gap-2 text-xs font-medium text-ink-400"><CalendarDays aria-hidden="true" size={14} />{t("profile.memberSince")}</dt>
                  <dd className="mt-2 text-sm font-semibold text-white">{formatDateTime(profile.createdAt)}</dd>
                </div>
                <div className="rounded-control border border-white/10 bg-white/[0.055] p-3.5">
                  <dt className="inline-flex items-center gap-2 text-xs font-medium text-ink-400"><ShieldCheck aria-hidden="true" size={14} />{t("profile.accountId")}</dt>
                  <dd className="mt-2 text-sm font-semibold text-white">#{formatNumber(profile.id)}</dd>
                </div>
              </dl>
            </div>
          </aside>

          <section className="card" aria-labelledby="personal-information-title">
            <div className="flex items-start gap-3 border-b border-border-subtle pb-5">
              <span className="icon-tile"><UserRound aria-hidden="true" size={19} /></span>
              <div>
                <p className="section-kicker">{t("profile.personalInfo")}</p>
                <h2 id="personal-information-title" className="mt-1 card-title">{t("profile.details")}</h2>
                <p className="mt-1 font-reading text-sm leading-6 text-ink-500">{t("profile.detailsCopy")}</p>
              </div>
            </div>

            <form className="mt-6 space-y-5" onSubmit={onSubmit}>
              <label className="field">
                <span className="inline-flex items-center gap-2"><UserRound aria-hidden="true" size={15} />{t("profile.fullName")}</span>
                <input
                  className="input"
                  dir="auto"
                  value={fullName}
                  onChange={(event) => {
                    setFullName(event.target.value);
                    setMessage("");
                    setError("");
                  }}
                  autoComplete="name"
                  maxLength={200}
                  required
                  disabled={saving}
                />
                <span className="field-hint">{t("profile.fullNameHint")}</span>
              </label>

              <div className="flex flex-col gap-3 border-t border-border-subtle pt-5 sm:flex-row sm:items-center sm:justify-between">
                <p className="text-xs leading-5 text-ink-500">{t("profile.changedOnly")}</p>
                <button className="btn-primary" type="submit" disabled={saving || !formChanged || !fullName.trim()}>
                  {saving ? <LoaderCircle aria-hidden="true" className="animate-spin" size={17} /> : <Save aria-hidden="true" size={17} />}
                  {saving ? t("profile.savingChanges") : t("profile.saveChanges")}
                </button>
              </div>
            </form>

            <EmailChangePanel
              currentEmail={profile.email}
              initialExpanded={searchParams.get("action") === "change-email"}
              onCompleted={(email) => {
                setProfile((current) => current ? { ...current, email } : current);
                setMessage("");
                setError("");
              }}
            />
          </section>
        </div>
      )}

      {cropSource && (
        <section className="content-swap-enter overflow-hidden rounded-card border border-border-subtle bg-white shadow-lift" aria-labelledby="crop-image-title">
          <div className="flex items-center justify-between gap-4 border-b border-border-subtle bg-surface-muted/50 px-5 py-4 sm:px-6">
            <div className="flex items-center gap-3">
              <span className="icon-tile"><Camera aria-hidden="true" size={18} /></span>
              <div>
                <p className="section-kicker">{t("profile.editor")}</p>
                <h2 id="crop-image-title" className="mt-0.5 card-title">{t("profile.cropTitle")}</h2>
              </div>
            </div>
            <button type="button" className="btn-icon size-10 min-h-10" aria-label={t("profile.closeEditor")} onClick={() => setCropSource(null)} disabled={uploadingImage}>
              <X aria-hidden="true" size={18} />
            </button>
          </div>

          <div className="grid gap-6 p-5 sm:p-6 lg:grid-cols-[1fr_18rem]">
            <div className="relative h-80 overflow-hidden rounded-control border border-border-subtle bg-surface-inverse shadow-inner sm:h-96">
              <Cropper
                image={cropSource}
                crop={crop}
                zoom={zoom}
                aspect={1}
                cropShape="round"
                showGrid={false}
                onCropChange={setCrop}
                onZoomChange={setZoom}
                onCropComplete={(_, croppedAreaPixels) => setCropPixels(croppedAreaPixels)}
              />
            </div>

            <div className="flex flex-col justify-between gap-6">
              <div>
                <div className="flex items-center gap-2 text-sm font-semibold text-ink-800">
                  <SlidersHorizontal aria-hidden="true" size={16} />
                  {t("profile.imageScale")}
                </div>
                <label className="field mt-4">
                  <span className="flex items-center justify-between"><span>{t("profile.zoom")}</span><span className="font-semibold text-brand-700">{formatNumber(zoom, { minimumFractionDigits: 1, maximumFractionDigits: 1 })}×</span></span>
                  <input
                    className="w-full accent-brand-600"
                    type="range"
                    min={1}
                    max={3}
                    step={0.1}
                    value={zoom}
                    onChange={(event) => setZoom(Number(event.target.value))}
                    disabled={uploadingImage}
                  />
                </label>
                <p className="mt-3 text-xs leading-5 text-ink-500">{t("profile.cropHint")}</p>
              </div>

              <div className="space-y-2">
                <button className="btn-primary w-full" type="button" disabled={uploadingImage || !cropPixels} onClick={() => void uploadCroppedImage()}>
                  {uploadingImage ? <LoaderCircle aria-hidden="true" className="animate-spin" size={17} /> : <Camera aria-hidden="true" size={17} />}
                  {uploadingImage ? t("profile.uploadingImage") : t("profile.saveImage")}
                </button>
                <button className="btn-secondary w-full" type="button" onClick={() => setCropSource(null)} disabled={uploadingImage}>{t("actions.cancel")}</button>
              </div>
            </div>
          </div>
        </section>
      )}

      {!loading && profile && <ProfileSupportHistory />}
    </div>
  );
}

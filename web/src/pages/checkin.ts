import { createButton } from "../components/button";
import { createCard } from "../components/card";
import { createInputField } from "../components/inputField";
import { showToast } from "../components/toast";
import { postCheckin } from "../lib/api";
import { buildCheckinProfile, saveCheckinProfile } from "../lib/checkin";
import type { CheckinProfileData, Department } from "../types";

const departments: Department[] = ["トータルモビリティ工学科", "CA/GS科", "整備科", "グランドハンドリング科"];

type CheckinPageOptions = {
  token?: string;
  onComplete: () => void;
};

export const renderCheckinPage = (options: CheckinPageOptions): HTMLElement => {
  const page = document.createElement("div");
  page.className = "grid";

  const header = document.createElement("div");
  header.className = "grid";
  header.innerHTML = `
    <div class="hero-title">ゲストチェックイン</div>
    <p class="muted">スマホのカメラで公式QRコードを読み取り、このページを開いてください。</p>
  `;

  if (!options.token) {
    const errorCard = createCard("トークンが見つかりません", `
      <p class="muted">公式QRコードを再度読み取り、正しいチェックインURLを開いてください。</p>
    `);
    errorCard.classList.add("form-error");
    page.append(header, errorCard);
    return page;
  }

  const form = document.createElement("form");
  form.className = "grid";

  const nameField = createInputField({ label: "お名前", placeholder: "山田 花子", name: "name" });
  const ageField = createInputField({ label: "年齢", placeholder: "18", name: "age", type: "number" });
  const schoolField = createInputField({ label: "高校名", placeholder: "〇〇高等学校", name: "highSchool" });

  const ageInputEl = ageField.querySelector("input");
  if (ageInputEl) {
    ageInputEl.min = "1";
    ageInputEl.max = "120";
    ageInputEl.inputMode = "numeric";
  }

  const departmentWrap = document.createElement("label");
  departmentWrap.className = "field";
  const departmentLabel = document.createElement("span");
  departmentLabel.className = "field__label";
  departmentLabel.textContent = "学科";
  const departmentSelect = document.createElement("select");
  departmentSelect.className = "field__input";
  departmentSelect.name = "department";
  const defaultOption = document.createElement("option");
  defaultOption.value = "";
  defaultOption.textContent = "選択してください";
  departmentSelect.appendChild(defaultOption);
  departments.forEach((dept) => {
    const option = document.createElement("option");
    option.value = dept;
    option.textContent = dept;
    departmentSelect.appendChild(option);
  });
  departmentWrap.append(departmentLabel, departmentSelect);

  const errorBox = document.createElement("div");
  errorBox.className = "form-errors";
  errorBox.hidden = true;

  const submitButton = createButton({ label: "チェックインする", variant: "primary" });
  submitButton.type = "submit";
  submitButton.classList.add("full-width");

  const cardBody = document.createElement("div");
  cardBody.className = "grid";
  cardBody.append(nameField, ageField, schoolField, departmentWrap, errorBox, submitButton);

  const card = createCard("基本情報を入力", cardBody);

  form.append(card);
  page.append(header, form);

  form.addEventListener("submit", async (event) => {
    event.preventDefault();
    errorBox.innerHTML = "";
    errorBox.hidden = true;

    const nameInput = nameField.querySelector("input");
    const ageInput = ageField.querySelector("input");
    const schoolInput = schoolField.querySelector("input");

    const errors: string[] = [];
    const name = nameInput?.value.trim() ?? "";
    const ageValue = Number(ageInput?.value ?? "");
    const highSchool = schoolInput?.value.trim() ?? "";
    const department = departmentSelect.value as Department;

    if (!name) errors.push("お名前を入力してください。");
    if (!Number.isFinite(ageValue) || ageValue < 1 || ageValue > 120) errors.push("年齢は1〜120の範囲で入力してください。");
    if (!highSchool) errors.push("高校名を入力してください。");
    if (!department || !departments.includes(department)) errors.push("学科を選択してください。");

    if (errors.length) {
      errorBox.innerHTML = `<ul>${errors.map((err) => `<li>${err}</li>`).join("")}</ul>`;
      errorBox.hidden = false;
      return;
    }

    const payload: CheckinProfileData = {
      name,
      age: ageValue,
      highSchool,
      department,
    };

    submitButton.setAttribute("disabled", "true");
    submitButton.classList.add("is-loading");

    try {
      const response = await postCheckin({ token: options.token, ...payload });
      saveCheckinProfile(buildCheckinProfile(payload, response.sessionId));
      showToast({ message: "チェックインが完了しました", tone: "success" });
      options.onComplete();
    } catch (err) {
      console.error(err);
      errorBox.innerHTML = "<ul><li>チェックインに失敗しました。時間をおいて再度お試しください。</li></ul>";
      errorBox.hidden = false;
      submitButton.removeAttribute("disabled");
      submitButton.classList.remove("is-loading");
    }
  });

  return page;
};

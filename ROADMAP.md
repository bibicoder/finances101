# 🗺️ Roadmap: Finance 101 — iOS App
> Started: 2026-05-29 | Updated: 2026-05-30

## 📊 Progress: 45 / 45 tasks complete (100%) 🎉

---

## 🎯 Продуктовая суть (читать перед каждой сессией)

Приложение создавалось НЕ для анализа прошлых расходов. Главная идея — **планирование будущего cashflow**:

```
Past expenses   = analyze (уже есть)
Current         = control (уже есть)
Future cashflow = PLAN    ← главный акцент, которого пока нет
```

Формула каждой недели:
```
Starting balance + Expected income − Planned expenses = Projected remaining
```

Пользователь должен планировать деньги наперёд, как в Notion/Excel, но быстрее и удобнее. Drag & drop расходов между неделями, быстрый ввод строкой "Gas 80" → Enter, связь wishlist → future expenses.

---

## 🏗️ Active Sprint — Фаза 5: Критичные баги

### ✅ B0 Color Contrast — Исправлено 2026-05-30
Белый текст на светлом фоне (primaryLight как фон/текст). ConnectBankView, DebtPayoffView, SettingsView, BalanceChartView. Все заменены на primaryDeep.

### ✅ B_Tabs Tabs "More" Bug — Исправлено 2026-05-30
6 вкладок → iOS создавал "More". Убрана Charity как отдельная вкладка. Charity History перенесён в Settings > Charity section. Теперь ровно 5 табов.

### ~~B1 Tab Bar Highlight Bug~~ ✅ 2026-06-01
Added `item.highlighted` state colors + `appearance.selectionIndicatorImage = UIImage()` in ContentView. Eliminates dark flash on tab tap.

### ~~B2 Plaid Balance Negative~~ ✅ 2026-06-01
Fixed `importSelected()` to use `totalDepositoryBalance` (all checking+savings, not just first account). Recalculates `initialBalance = bankBalance - allPaidIncome + allPaidExpenses` using ALL existing transactions, not just newly imported batch. Root cause: pre-existing manual transactions were overcounting income.

### ~~B3 FamilyView/MyView Logic Review~~ ✅ 2026-06-01
UserRoleManager now persists last role to UserDefaults. If last role was viewer → starts as viewer without PIN. If PIN exists and last role was owner → shows lock screen. After background → always re-prompts (security). My View = PIN-protected, Family View = no PIN (correct behavior, just not persisted before).

### ~~B4 Multi-Account Balance Display~~ ✅ 2026-06-01
AppSettings now stores `plaidCashBalance`, `plaidCreditBalance`, `plaidSyncedAt`. PlaidImportView saves these on sync. BalanceBreakdownSheet shows "Bank Accounts" section when Plaid data exists: Cash (checking+savings), Credit Card Debt (separate), Net = Cash − Credit.

---

## 📋 Backlog

### ~~Фаза 6 — Future Budget Planning~~ ✅ 2026-06-01

#### ~~6.1 Weekly Planning View~~ ✅ 2026-06-01
**Что это:** Новый экран (новый таб или sub-view внутри Plans), где пользователь видит расходы по неделям и планирует будущий бюджет.

**Как должно выглядеть:**
```
Week 1  (Jun 2–8)          Starting: $1,000
  + Paycheck               $2,500
  − Rent                   $1,200
  − Groceries              $150
  − Gas                    $80
  Projected end:           $2,070  ←← главная цифра

Week 2  (Jun 9–15)
  − Insurance              $180
  − Phone                  $70
  Projected end:           $1,820

Week 3  (Jun 16–22)
  − Car repair (planned)   $400
  Projected end:           $1,420
```

**Ключевые фичи:**
- Каждый expense и income можно перетащить в другую неделю (drag & drop)
- Projected balance пересчитывается в реальном времени
- Можно добавить expense прямо внутри недели (inline)
- Статус: planned / paid / postponed

**Почему важно:** Пользователь сейчас делает это в Notion/Excel. Приложение должно заменить этот процесс.

#### ~~6.2 Quick Expense Entry — строка + Enter~~ ✅ 2026-06-01
**Что это:** Быстрое добавление расхода без открытия отдельной формы.

**Как должно работать:**
```
Пользователь печатает: "Gas 80"
→ Enter
→ Создаётся ExpenseEntry: title="Gas", amount=80, category=Transportation (авто)
```

```
"Rent 1200 week1"
→ ExpenseEntry: title="Rent", amount=1200, week=Week1, category=Housing
```

**Автодетект:** приложение парсит строку и определяет:
- Число = сумма
- Слово/слова = название
- "week1"/"next week"/"friday" = дата/неделя
- По названию угадывает категорию (см. 6.3)

**Где показывать:** Поле ввода внизу Weekly Planning View или Timeline. Не отдельный sheet.

#### ~~6.3 Auto-Categorization~~ ✅ 2026-06-01
**Что это:** При создании expense через строку (или обычную форму) приложение предлагает категорию автоматически.

**Словарь правил:**
```
Gas, Fuel, Shell, BP, Chevron       → Transportation
Groceries, Whole Foods, Trader Joe  → Food & Groceries
Rent, Mortgage, Lease               → Housing
Netflix, Spotify, Hulu, subscription→ Subscriptions
Insurance, Geico, State Farm        → Insurance
Gym, Planet Fitness                 → Health & Fitness
Amazon, Target, Walmart             → Shopping
Dentist, Doctor, Pharmacy           → Healthcare
School, Tuition                     → Education
```

**UX:** Показывать предложенную категорию как chip, который можно тапнуть чтобы изменить. Не блокировать — просто предложение.

#### ~~6.4 Drag & Drop Between Weeks~~ ✅ 2026-06-01
**Что это:** В Weekly Planning View пользователь может зажать expense и перетащить его в другую неделю.

**Поведение:**
- Long press → item "поднимается" (scale + shadow)
- Drag → видно, над какой неделей находится
- Drop → item перемещается, projected balance обеих недель пересчитывается

**Также нужно:** Drag из Wishlist в любую неделю (см. 6.5).

**Почему важно:** Если клиент задержал оплату — просто перетащить "Client payment $800" из Week 1 в Week 2. Если не успел починить машину — перетащить "Car repair $500" на следующую неделю. Планирование должно быть гибким.

#### ~~6.5 Wishlist → Future Expenses~~ ✅ 2026-06-01
**Что это:** Связь между Wishlist и Weekly Planning. Пользователь может переместить wishlist item в конкретную неделю → он становится planned expense.

**Логика:**
```
Wishlist:
  "New tires — $600"
  "Trip to Dallas — $300"
  "New laptop — $1,200"

Drag "New tires" → Week 3
→ WishlistItem переходит в статус "planned"
→ Создаётся ExpenseEntry в Week 3: title="New tires", amount=600
→ Week 3 projected balance уменьшается на $600
```

**UX:** В Wishlist добавить кнопку "Schedule" или поддержать drag прямо на недельный view.

#### ~~6.6 Cashflow Projection per Week~~ ✅ 2026-06-01
**Что это:** Автоматический расчёт projected balance для каждой будущей недели на основе запланированных доходов и расходов.

**Формула:**
```
Week N projected =
  Week (N-1) projected end balance
  + sum(expected incomes in Week N)
  − sum(planned expenses in Week N)
```

**Отображение:** Внизу каждой недели в Weekly Planning View — зелёная/красная цифра "Projected: $X". Если уходит в минус — красный цвет + предупреждение.

---

### ~~Фаза 7 — Income Planning~~ ✅ 2026-06-01

#### ~~7.1 Quick Income Entry~~ ✅ 2026-06-01
**Что это:** То же самое, что 6.2, но для доходов. Строка → Enter → создан income.

**Как должно работать:**
```
"Paycheck 2500"
→ IncomeEntry: title="Paycheck", amount=2500, status=expected

"Client payment 700 next week"
→ IncomeEntry: title="Client payment", amount=700, week=next, status=expected

"Roman 1200"
→ IncomeEntry: title="Roman", amount=1200, status=expected
```

**Автодетект source type:** Salary, Freelance, Rental, Transfer, Other — по ключевым словам в названии.

#### ~~7.2 Recurring Income~~ ✅ 2026-06-01
**Что это:** Шаблоны для повторяющихся доходов. Аналог RecurringTemplate, но для income.

**Примеры:**
```
Salary → every 2 weeks (bi-weekly), Friday
Rent income → monthly, 1st of month
Side project → monthly, 15th
```

**Поведение:**
- Создать recurring income template
- Приложение авто-генерирует будущие IncomeEntry на горизонт (90 дней)
- Можно изменить один конкретный future income без изменения шаблона
- При получении дохода — тапнуть "Mark as Received" → статус меняется

#### ~~7.3 Income Status: Expected / Received / Delayed / Cancelled~~ ✅ 2026-06-01
**Что это:** Статусы для income, чтобы видеть реальную картину, а не просто план.

**Статусы:**
```
Expected   — запланирован, ещё не пришёл (серый/синий)
Received   — деньги получены (зелёный) 
Delayed    — должен был прийти, но задержался (жёлтый)
Cancelled  — отменён (красный, зачёркнут)
```

**Почему важно:** Для contractors, freelancers, business owners доход нестабилен. "Expected $3000 from client" ≠ деньги в кармане. Нужно отделять план от реальности.

#### ~~7.4 Weekly Income View~~ ✅ 2026-06-01
**Что это:** Income тоже отображается в Weekly Planning View рядом с expenses.

**Поведение:**
- Income можно drag & drop между неделями (клиент задержал — переносим)
- Разные цвета: income зелёный, expense красный
- Delayed income помечается особо, не учитывается в projected balance (или учитывается отдельной строкой)

---

### ~~Фаза 8 — Family Mode 2.0~~ ✅ 2026-06-01

#### ~~8.1 FamilyView from Another Phone~~ ✅ 2026-06-01
**Проблема:** Сейчас FamilyView доступен только на одном телефоне через переключение режима внутри приложения. Жена не может зайти в FamilyView со своего iPhone.

**Что нужно реализовать:** Один из вариантов (нужно выбрать и согласовать):

**Вариант A — iCloud Family:**
Использовать уже реализованный iCloud Sync (2.3). Жена устанавливает приложение, входит в тот же iCloud — данные синхронизируются. При первом запуске она выбирает "Family Member" → ограниченный режим.

**Вариант B — Invite Code:**
Владелец генерирует 6-значный код в Settings → Share → жена вводит код при установке → получает FamilyView.

**Вариант C — QR-код:**
Владелец показывает QR в приложении, жена сканирует → получает доступ.

**Рекомендация:** Вариант A (iCloud) уже есть инфраструктура. Добавить только логику "при первом запуске на новом устройстве — выбрать роль".

#### ~~8.2 Owner/Viewer Permission Redesign~~ ✅ 2026-06-01
**Проблема:** Сейчас код защищает FamilyView, а должен защищать MyView (личный экран владельца).

**Нужная логика:**
```
MyView   = полный доступ, защищён PIN владельца
           (редактирование всего: транзакции, настройки, долги, charity)

FamilyView = ограниченный просмотр, без кода
             (видит: баланс, расходы, доходы, wishlist)
             (не видит/не редактирует: настройки, долги, charity, Plaid)
```

**Поведение при запуске:**
- Приложение помнит последний выбранный режим
- Если в MyView — при открытии сразу в MyView (PIN уже введён в сессии)
- Если хочешь переключить на FamilyView — кнопка в Settings или смахивание
- Из FamilyView в MyView — требует PIN

---

### Фаза 3 (остаток)

#### ~~3.6 Прогноз накоплений~~ ✅ 2026-06-01
Секция "Savings Forecast" в AnalyticsView: avg monthly savings (last 3 months), прогноз 3/6/12 мес. с bar-индикаторами и badge темпа.

#### ~~3.7 Поиск и фильтры в Timeline~~ ✅ 2026-06-01
SearchBar + type chips (All/Income/Expense/Charity) + filter sheet (amount range, date range). Toolbar filter icon с badge когда активен.

#### ~~3.8 Push-уведомления~~ ✅ 2026-06-01
NotificationManager (UNUserNotification): planned expenses 1 день до, debt target dates, subscriptions (notifyDaysBefore). Секция в Settings с toggle + под-toggles. Schedules on app launch.

#### ~~3.9 Split транзакции~~ ✅ 2026-06-01
Toggle "Split by Category" в AddExpenseSheet. Динамические строки (category + amount), balance indicator, создаёт отдельный ExpenseEntry на каждый split. No model changes.

---

### Фаза 4 — Масштаб и синхронизация

#### ~~4.2 Импорт CSV из банка~~ ✅ 2026-06-01
CSVImportParser (Chase/BOA/WellsFargo/generic), авто-категоризация по ключевым словам. CSVImportView: filePicker → preview с checkboxes → import. Кнопка в Settings > Data.

#### ~~4.3 Сканирование чеков~~ ✅ 2026-06-01
ReceiptScannerView: VNDocumentCamera → Vision OCR → extracts total + merchant. Camera button в AddExpenseSheet toolbar. Auto-fills amount + title.

#### ~~4.4 Экспорт PDF~~ ✅ 2026-06-01
UIGraphicsPDFRenderer в ExportManager. Отчёт: Summary + Income by Category + Expenses by Category + Debts. Периоды: этот месяц / 3 мес / год. Share sheet.

#### ~~4.5 Виджет Home Screen~~ ✅ 2026-06-01
Finance101Widget (small/medium). WidgetDataWriter пишет в App Group UserDefaults из HomeView. Код готов — добавить Extension target в Xcode (см. Finance101Widget/WIDGET_SETUP.md).

#### ~~4.6 Мульти-кошельки~~ ✅ 2026-06-01
Wallet + WalletTransfer модели. WalletsView (новый таб), AddWalletSheet, WalletTransferSheet, WalletDetailSheet. walletId в Income/Expense. Wallet picker в AddExpenseSheet.

#### ~~4.7 Год к году сравнение~~ ✅ 2026-06-01
Секция Year-over-Year в AnalyticsView: последние 6 месяцев, горизонтальные bar charts (этот год vs прошлый год), % изменение.

---

## ✅ Completed — Фазы 1–3 (часть)

- [x] **1.1** Валидация форм — пустая сумма, отрицательные числа ✅ 2026-05-29
- [x] **1.2** Charity onPaid режим — логика написана в StatusUpdateManager ✅ 2026-05-29
- [x] **1.3** defaultHorizonDays из Settings подключён в ContentView (было захардкожено 90 дней) ✅ 2026-05-29
- [x] **1.4** Decimal арифметика исправлена (CharityAccrual — больше не через Double) ✅ 2026-05-29
- [x] **1.5** try? modelContext.save() заменён на try с логированием ошибок ✅ 2026-05-29
- [x] **1.6** Логика charity централизована — убраны дубли из 3 мест ✅ 2026-05-29
- [x] **1.7** BalanceCalculator кешируется — нет пересчёта при каждом рендере HomeView ✅ 2026-05-29
- [x] **1.8** Платёж долга вынесен из аналитики расходов (DebtRowView) ✅ 2026-05-29
- [x] **1.9** Мягкое удаление реализовано (isDeleted флаг) ✅ 2026-05-29
- [x] **2.1 Charity Mode 2.0** — % от дохода / фиксированная сумма / комбинированный. Переключение в Settings. ✅ 2026-05-29
- [x] **2.2 Wife Mode** — Отдельный PIN в Keychain, UserRole enum (owner/viewer). ✅ 2026-05-30
- [x] **2.3 iCloud Sync** — SwiftData + CloudKit между устройствами. ✅ 2026-05-30
- [x] **2.4 Bank Integration (Plaid)** — OAuth, автоимпорт транзакций, автокатегоризация. ✅ 2026-05-30
- [x] **3.1 Трекер подписок** — Recurring платежи, автодетект, напоминания, сумма в месяц/год. ✅ 2026-05-30
- [x] **3.2 Debt Payoff калькулятор** — Avalanche + snowball, график погашения, дата выплаты. ✅ 2026-05-30
- [x] **3.3 Финансовый Health Score** — 0–100 на основе savings rate, долга, charity, бюджета. ✅ 2026-05-30
- [x] **3.4 Бюджет по категориям** — Лимит на категорию, план vs факт, алерт при превышении. ✅ 2026-05-30
- [x] **3.5 Net Worth экран** — Активы − Долги = Net Worth, график динамики. ✅ 2026-05-30
- [x] **3.10 Financial Insights** — Локальный движок советов: бюджет, savings rate, спайки, APR, подписки. ✅ 2026-05-30

# 🗺️ Roadmap: Finance 101 — iOS App
> Started: 2026-05-29 | Updated: 2026-06-12

## 📊 Progress: 72 / 73 tasks complete

---

## ✅ Фаза 15 — Производительность (фикс лагов) ✅ 2026-06-13

- [x] **15.1 Перфоманс-рефакторинг тяжёлых экранов** — Analytics и Spending пересчитывали десятки O(n)-фильтров и создавали BalanceCalculator (7 fetch'ей к БД) на КАЖДЫЙ рендер; в Analytics `currentBalance` дёргался ~8 раз за кадр → 50+ запросов к БД на рендер. Переведены на кэш-паттерн HomeView: всё считается один раз в `@State` через `recompute()` на onAppear + onChange(dataVersion/period). График баланса: цикл переписан с O(дни×транзакции) на O(n) через bucket по дням, + даунсемплинг до 90 точек (Year было ~390). НЕ переписывал логику, только устранил повторный пересчёт. ✅ 2026-06-13 (M)

---

## 🏗️ Active — Фаза 14: Где люди хранят деньги

- [x] **14.1 Стейблкоины USDT/USDC + TRON** — Токены USDT и USDC на Ethereum (ERC-20), BNB (BEP-20) и Tron (TRC-20) + нативный TRX. EVM-токены через eth_call balanceOf, TRON через TronGrid. CryptoChain расширен до 14 кейсов, цены tether/usd-coin/tron с CoinGecko. ✅ 2026-06-12 (M)
- [x] **14.2 Ручные активы** — Баланс не-крипто кошелька теперь редактируется в WalletDetailSheet (золото, акции, PayPal, Wise, валюта). Подсказки в AddWalletSheet: Savings/Investment → вне Safe-to-Spend. ✅ 2026-06-12 (S)
- [ ] **14.3 Биржи по read-only API-ключу** — Binance/Bybit/Coinbase: спот-балансы по API-ключу (HMAC-подпись, секрет в Keychain). Отдельный механизм (не адрес), по бирже за раз. Начать с Binance. ⏳ отложено — крупная и безопасностно-чувствительная (L)

---

## ✅ Фаза 13 — Реальные деньги, мульти-банк, аудит логики ✅ 2026-06-12

- [x] **13.1 Баланс по «available», а не «current»** — Total Balance берёт available (реальные тратимые деньги), current показывается мелким как «statement». PlaidSyncService.spendableCash = available ?? current. ✅ 2026-06-12 (S)
- [x] **13.2 Разбивка по банкам + никнеймы** — Каждый банк хранит свой cash/credit/syncedAt в PlaidConnection (Keychain). Дашборд: отдельный чип на банк по имени; Breakdown: строка на банк; Settings: переименование банка (TextField) + баланс. ✅ 2026-06-12 (M)
- [x] **13.3 Больше крипто-сетей** — Было BTC/ETH, стало 8: +LTC, DOGE, SOL, BNB, Polygon, Avalanche. EVM-сети через общий eth_getBalance, цены с CoinGecko динамически по всем priceId. ✅ 2026-06-12 (M)
- [x] **13.4 Фикс 2D-скролла в Spending + график** — Ось X: 4 метки + месяцы для длинных диапазонов (было 52 налезающих); chartXScale padding. Транзакции по неделям. Balance Over Time привязан к реальному балансу (был дрейф в −$5000). ✅ 2026-06-12 (S)
- [x] **13.5 Аудит логики баланса (КРИТИЧНО)** — Найдены и исправлены 3 бага: (а) добавление кошелька обнуляло старые un-walleted транзакции; (б) после «Disconnect All» баланс держал устаревший plaidCashBalance; (в) HealthScore/NetWorth/Analytics считали баланс по старой леджер-формуле → минус для Plaid-юзеров. Единое уравнение: банк(live) + кошельки + крипта + loose cash. reanchor больше не портит initialBalance. ✅ 2026-06-12 (L)

---

## ✅ Фаза 12 — Баланс = реальные деньги ✅ 2026-06-12

- [x] **12.3 Транзакции в Spending по неделям (collapsible)** — Вместо плоского списка «последние 10»: группировка по прошедшим неделям, компактные свернутые строки (неделя + кол-во + итог), раскрытие по тапу, текущая неделя раскрыта по умолчанию. Переиспользован PlanWeek для подписей. ✅ 2026-06-12 (S)
- [x] **12.2 Фикс налезающих дат на графике Balance Over Time** — Ось X была жёстко «каждые 7 дней» → на Month/Year ~50 подписей друг на друге. Теперь 4 метки на любом диапазоне; при диапазоне >120 дней — только месяц (Jan, Apr…), иначе день+месяц. ✅ 2026-06-12 (S)
- [x] **12.1 Новая модель баланса и Safe-to-Spend** — Total Balance теперь = банк (последний Plaid-синк) + ручные кошельки (кэш и т.д.) + крипта. Записи без кошелька (вкл. Plaid-импорт) больше НЕ двигают баланс — банк их уже отразил (раньше баланс «уезжал» между синками и двоился с импортом). Hero-карта снизу: Received / Spent / Saved за ЭТУ неделю (раньше — 30-дневный прогноз). Safe-to-Spend = баланс − планы этой недели (вкл. просроченные), без вычета charity/savings. Чип "Bank" в строке кошельков. Legacy-режим (без Plaid и кошельков) сохранён: стартовый баланс ± леджер. ✅ 2026-06-12 (M)

---

## ✅ Фаза 11 — Реальный баланс, Multi-Bank, Crypto ✅ 2026-06-12

- [x] **11.1 Кошельки на дашборде** — Чипы кошельков с балансами прямо на hero-карте; секция Wallets в Balance Breakdown; карточка "Set Aside (Savings)"; кошельки учитываются в Total Balance; savings/investment/crypto исключены из Safe-to-Spend. Выбор кошелька добавлен и в форму дохода. ✅ 2026-06-12 (M)
- [x] **11.2 Фикс математики баланса (минус на дашборде)** — Старое уравнение Plaid-синка теряло charity-платежи и кошельки → после каждого синка баланс уезжал вниз. Новое уравнение в PlaidSyncService.reanchorBalance: Total == банковский кэш + балансы ручных кошельков, всегда. ✅ 2026-06-12 (M)
- [x] **11.3 Авто-синк банка** — PlaidSyncService: при запуске (троттлинг 4 ч) и pull-to-refresh на дашборде тянет балансы + новые транзакции из ВСЕХ банков, дедупликация по transaction_id. Расходы сами появляются в приложении. ✅ 2026-06-12 (M)
- [x] **11.4 Банковские транзакции в неделях** — Оплаченные расходы/доходы показываются в своей неделе Weekly-плана (приглушённые, с галочкой и пометкой paid/received). В проекцию не входят — они уже внутри баланса. ✅ 2026-06-12 (S)
- [x] **11.5 Multi-Institution Plaid** — Несколько банков одновременно (Chase + Cash App + ...). PlaidManager хранит массив подключений в Keychain (миграция со старого одиночного токена). Settings: список банков, добавить/удалить по одному. Импорт и синк агрегируют все. ✅ 2026-06-12 (M)
- [x] **11.6 Крипто-кошелёк по адресу** — Тип кошелька Crypto: вставляешь ПУБЛИЧНЫЙ адрес (BTC через Blockstream API / ETH через public RPC), цена с CoinGecko. Read-only, без ключей и логинов. USD-стоимость входит в Total Balance и Net Worth, исключена из Safe-to-Spend. Обновление при открытии Wallets и pull-to-refresh. ✅ 2026-06-12 (M)

---

## ✅ Фаза 10 — Weekly Planning UX

- [x] **10.1 Quick Add 2.0 (категории)** — После "Gas 80"+Enter открывается компактное окошко (420pt half-sheet): сетка категорий с цветами, авто-категория подсвечена. Тап по категории = сохранить с ней; свайп вниз = сохранить с авто-категорией. Долгое нажатие на строку → подменю "Category" для смены. Строки расходов окрашены цветом категории (иконка + подпись). Бонус-фикс: автокатегоризация возвращала "Transportation", а канонические категории — "Transport" (записи падали в Other). ✅ 2026-06-11 (M)

---

## ✅ Фаза 9 — Production Audit (полный аудит кода, big-company стандарты) ✅ 2026-06-11

- [x] **9.1 iCloud Sync реально не работал** — SwiftData+CloudKit требует inline-дефолты у всех полей модели; контейнер падал и молча откатывался на локальное хранилище. Добавлены дефолты во все 12 моделей + лог фолбэка в finances101App. ✅ 2026-06-11
- [x] **9.2 Регрессия "More" таба** — Wallets (4.6) вернул 6-й таб → iOS снова создавал меню "More". Wallets перенесён в Settings > Wallets & Transfers, снова ровно 5 табов. ✅ 2026-06-11
- [x] **9.3 Safe-to-Spend считался неверно** — mandatory-расходы вычитались дважды (внутри projected и отдельно). Новая консервативная формула: actualBalance − charityOwed − обязательные платежи (mandatory + recurring) на 30 дней. Ожидаемые, но не полученные доходы больше не считаются. ✅ 2026-06-11
- [x] **9.4 Charity скрывалась в Fixed/Combined режимах** — UI гейтился только по charityPercentage > 0. Добавлен AppSettings.isCharityActive с учётом режима. ✅ 2026-06-11
- [x] **9.5 Баланс на Home не обновлялся при редактировании** — версия коллекций учитывала только количество записей; изменение суммы/статуса не триггерило пересчёт. В версию добавлены суммы и paid-счётчики. ✅ 2026-06-11
- [x] **9.6 Запятая в суммах ломала ввод** — Decimal(string:) понимает только точку; на ru/tr/eu клавиатурах "12,50" превращалось в 12. Новый Decimal(userInput:) — все 33 места ввода обновлены. ✅ 2026-06-11
- [x] **9.7 Повторный Plaid-импорт дублировал транзакции** — добавлен externalId (transaction_id) в Income/Expense, дедупликация при загрузке и при импорте. ✅ 2026-06-11
- [x] **9.8 Точность денег из Plaid** — Double→Decimal давал артефакты (12.300000000000001). Новый Decimal(money:) с банковским округлением до 2 знаков. ✅ 2026-06-11
- [x] **9.9 Monthly recurring дрейфовал** — "ежемесячно" было +30 дней (1 янв → 31 янв → 2 мар). Теперь календарный месяц (1-е число остаётся 1-м). + Защита от бесконечного цикла при customDays=0. ✅ 2026-06-11
- [x] **9.10 PIN хранился открытым текстом** — теперь SHA-256 хеш в Keychain с автоматической миграцией существующих PIN. + Лимит iOS в 64 уведомления: ближайшие 60 по дате вместо случайного отбрасывания. ✅ 2026-06-11

### ⚠️ Известные риски (не баги — требуют решения владельца)
1. **Автостатус income** — StatusUpdateManager автоматически помечает planned/earned доходы как Paid при наступлении даты. Это противоречит фиче Delayed (7.3): задержанный платёж клиента сам "станет полученным". Менять = изменится баланс у текущих пользователей. Решить: авто-Paid или авто-Delayed.
2. **Виджет** — требует ручного шага: добавить Widget Extension target + App Group `group.com.finances101` в entitlements (см. Finance101Widget/WIDGET_SETUP.md). Без App Group данные в виджет не попадают.
3. **CloudKit на устройстве** — после фикса 9.1 проверить реальную синхронизацию на двух устройствах с одним iCloud (первый запуск может занять минуты).

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

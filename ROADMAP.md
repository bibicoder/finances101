# 🗺️ Roadmap: Finance 101 — iOS App
> Started: 2026-05-29 | Updated: 2026-05-30

## 📊 Progress: 19 / 45 tasks complete (42%)

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

### B1 Tab Bar Highlight Bug (S)
**Симптом:** При нажатии на вкладку нижнего бара (Dashboard / Spendings / Plans / Analytics / More) вкладка резко темнеет и "залипает" тёмным фоном на ~0.5–1 сек, потом становится прозрачной снова. Ощущение лага или зависания.
**Причина:** Скорее всего лишний `@State` ре-рендер всего ContentView при смене таба, или кастомный `.background` + анимация на TabView item конфликтуют.
**Нужно:** Убрать тёмный highlight при tap, сделать переключение мгновенным и плавным. Проверить, не происходит ли полный reload view при каждом нажатии.

### B2 Plaid Balance Negative (M)
**Симптом:** Plaid подключён, транзакции видны, но баланс показывает отрицательное число, хотя реально деньги на счёте есть.
**Возможные причины:**
- Используется `available` вместо `current` balance
- Credit card balance показывается как negative cash (это правильно для кредитки, но не для checking)
- Баланс считается вручную через сумму транзакций вместо того, чтобы брать из Plaid напрямую
- Расходы вычитаются дважды (из Plaid + из локальных записей)
- Не обрабатываются разные account types (checking vs savings vs credit)
**Нужно:** Для checking/savings показывать реальный текущий баланс из Plaid. Credit card — отображать отдельно как долг, не мешать с cash balance.

### B3 FamilyView/MyView Logic Review (M)
**Симптом:** При перезапуске приложения показывается экран выбора MyView / FamilyView. Код/PIN стоит на FamilyView, но логически защищать нужно MyView (личный экран владельца), а не FamilyView.
**Нужно разобраться:**
- Как сейчас реализован UserRole (owner/viewer) — где хранится, как переключается
- Почему код на FamilyView, а не на MyView
- Запоминается ли последний выбранный режим после перезапуска
- Что происходит: приложение каждый раз спрашивает режим или только первый раз
**Цель:** Владелец = заходит в MyView, защищён PIN. Жена/член семьи = заходит в FamilyView (ограниченный просмотр). Переключение органичное, без путаницы.

### B4 Multi-Account Balance Display (M)
**Симптом:** Несколько банковских счетов через Plaid, но общий баланс считается как одна цифра без разделения типов.
**Нужно:** Разделить на категории:
```
Total cash:     checking + savings
Credit cards:   показывать как долг, не прибавлять к cash
Debt:           отдельно
Planned out:    запланированные расходы
Net balance:    cash − planned expenses
```
Не складывать всё в одну цифру. Кредитка с балансом $3000 — это не +$3000 к кошельку.

---

## 📋 Backlog

### Фаза 6 — Future Budget Planning ← ГЛАВНОЕ НОВОЕ НАПРАВЛЕНИЕ

#### 6.1 Weekly Planning View (L)
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

#### 6.2 Quick Expense Entry — строка + Enter (M)
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

#### 6.3 Auto-Categorization (M)
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

#### 6.4 Drag & Drop Between Weeks (M)
**Что это:** В Weekly Planning View пользователь может зажать expense и перетащить его в другую неделю.

**Поведение:**
- Long press → item "поднимается" (scale + shadow)
- Drag → видно, над какой неделей находится
- Drop → item перемещается, projected balance обеих недель пересчитывается

**Также нужно:** Drag из Wishlist в любую неделю (см. 6.5).

**Почему важно:** Если клиент задержал оплату — просто перетащить "Client payment $800" из Week 1 в Week 2. Если не успел починить машину — перетащить "Car repair $500" на следующую неделю. Планирование должно быть гибким.

#### 6.5 Wishlist → Future Expenses (M)
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

#### 6.6 Cashflow Projection per Week (M)
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

### Фаза 7 — Income Planning

#### 7.1 Quick Income Entry (M)
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

#### 7.2 Recurring Income (M)
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

#### 7.3 Income Status: Expected / Received / Delayed / Cancelled (S)
**Что это:** Статусы для income, чтобы видеть реальную картину, а не просто план.

**Статусы:**
```
Expected   — запланирован, ещё не пришёл (серый/синий)
Received   — деньги получены (зелёный) 
Delayed    — должен был прийти, но задержался (жёлтый)
Cancelled  — отменён (красный, зачёркнут)
```

**Почему важно:** Для contractors, freelancers, business owners доход нестабилен. "Expected $3000 from client" ≠ деньги в кармане. Нужно отделять план от реальности.

#### 7.4 Weekly Income View (M)
**Что это:** Income тоже отображается в Weekly Planning View рядом с expenses.

**Поведение:**
- Income можно drag & drop между неделями (клиент задержал — переносим)
- Разные цвета: income зелёный, expense красный
- Delayed income помечается особо, не учитывается в projected balance (или учитывается отдельной строкой)

---

### Фаза 8 — Family Mode 2.0

#### 8.1 FamilyView from Another Phone (L)
**Проблема:** Сейчас FamilyView доступен только на одном телефоне через переключение режима внутри приложения. Жена не может зайти в FamilyView со своего iPhone.

**Что нужно реализовать:** Один из вариантов (нужно выбрать и согласовать):

**Вариант A — iCloud Family:**
Использовать уже реализованный iCloud Sync (2.3). Жена устанавливает приложение, входит в тот же iCloud — данные синхронизируются. При первом запуске она выбирает "Family Member" → ограниченный режим.

**Вариант B — Invite Code:**
Владелец генерирует 6-значный код в Settings → Share → жена вводит код при установке → получает FamilyView.

**Вариант C — QR-код:**
Владелец показывает QR в приложении, жена сканирует → получает доступ.

**Рекомендация:** Вариант A (iCloud) уже есть инфраструктура. Добавить только логику "при первом запуске на новом устройстве — выбрать роль".

#### 8.2 Owner/Viewer Permission Redesign (M)
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

#### 3.6 Прогноз накоплений (S)
На основе среднего income и expenses за последние 3 месяца: сколько накопишь за 3/6/12 месяцев при текущем темпе. Простой линейный прогноз + карточка на HomeView или в Analytics.

#### 3.7 Поиск и фильтры в Timeline (S)
Поле поиска по названию + фильтры: по категории, диапазону дат, сумме (от/до), типу (income/expense/debt). Реализовать через SwiftData predicate или локальный filter на массиве.

#### 3.8 Push-уведомления (S)
Локальные UNUserNotification:
- Напоминание за 1 день до planned expense
- Напоминание о предстоящем долговом платеже
- Напоминание о recurring subscription
Запрос разрешения при первом открытии Settings → Notifications.

#### 3.9 Split транзакции (M)
Один expense разбивается на несколько категорий. Пример: $100 ужин → $60 Food + $40 Entertainment. В форме создания/редактирования expense — кнопка "Split" → добавить строки с суммами, сумма должна = total.

---

### Фаза 4 — Масштаб и синхронизация

#### 4.2 Импорт CSV из банка (M)
Парсинг банковских выписок: Chase, Bank of America, Wells Fargo формат. Маппинг колонок → IncomeEntry или ExpenseEntry. Дедупликация (не создавать дубли если уже есть через Plaid). UI: выбрать файл → превью → подтвердить импорт.

#### 4.3 Сканирование чеков (M)
OCR через встроенный Vision framework (бесплатно, не нужен внешний API). Камера → распознать сумму и название → предзаполнить форму AddExpense. Опционально: распознать дату.

#### 4.4 Экспорт PDF (S)
Отчёт за выбранный период (месяц/квартал/год): доходы, расходы по категориям, charity, долги, net worth. Использовать PDFKit или UIGraphicsPDFRenderer. Поделиться через Share sheet.

#### 4.5 Виджет Home Screen (M)
WidgetKit. Размеры small и medium. Small: текущий баланс. Medium: баланс + safe-to-spend + ближайший крупный расход. Обновляется при открытии приложения через App Group shared container.

#### 4.6 Мульти-кошельки (L)
Отдельные счета: Наличка / Карта / Сбережения / Бизнес. Каждая транзакция привязана к кошельку. Общий баланс = сумма всех кошельков. Переводы между кошельками — отдельный тип транзакции (не income и не expense).

#### 4.7 Год к году сравнение (S)
В Analytics: этот месяц vs тот же месяц прошлого года. Динамика по категориям. Простой bar chart или line chart.

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

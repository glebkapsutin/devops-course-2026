# Отчёт по практической работе №3

**Тема:** Продвинутые техники Git: Rebase, Squash, конфликты и Multi-Remote  
**Студент:** Капустин Глеб  
**Группа:** ЭФБО-10-24

## Задание 1. Разрешение merge-конфликта

В двух параллельных ветках были созданы разные версии `README.md`. При слиянии Git обнаружил add/add-конфликт. Содержимое обеих версий было осмысленно объединено, а маркеры конфликта удалены.

### До разрешения

![README с маркерами конфликта](assets/01_readme_conflict.png)

### После разрешения

![README после разрешения конфликта](assets/02_readme_resolved.png)

## Задание 2. Merge и Rebase

### История после merge

![Нелинейная история с merge-коммитом](assets/03_merge_history.png)

При `merge` сохраняются обе линии разработки и создаётся отдельный merge-коммит. История точно отражает параллельную работу, но становится разветвлённой.

### История после rebase

![Линейная история после rebase](assets/04_rebase_history.png)

При `rebase` коммиты feature-ветки были перенесены поверх актуального `main`. История стала линейной и читается последовательно, без дополнительного merge-коммита.

## Задание 3. Interactive Rebase

### История до rebase

![Грязная история из шести коммитов](assets/05_dirty_history.png)

### История после rebase

![Три чистых коммита](assets/06_clean_history.png)

Через interactive rebase были выполнены `fixup` для рабочих исправлений, `drop` для пустого коммита и переименование итоговых коммитов по Conventional Commits.

### Итоговый calculator.py

![Файл calculator.py после rebase](assets/07_calculator_after_rebase.png)

## Задание 4. Multi-Remote

Для репозитория используются два удалённых адреса:

- `origin` — основной репозиторий `glebkapsutin/devops-course-2026`;
- `mirror` — резервный репозиторий `glebkapsutin/devops-course-2026-mirror`.

После создания зеркала все ветки и теги отправляются в оба репозитория, а тестовый коммит проверяет синхронизацию.

## Задание 5. Cherry-pick, Reflog и Revert

### Cherry-pick

Из ветки `hotfix/urgent-fix` в `main` был перенесён только критический фикс. Экспериментальные функции `multiply` и `divide` в `main` не попали.

![Cherry-pick в истории main](assets/08_cherrypick_history.png)

![calculator.py после cherry-pick](assets/09_calculator_after_cherrypick.png)

### Reflog

Ветка с `important_data.md` была удалена, после чего хеш потерянного коммита найден через `git reflog`. Из этого хеша временно создана восстановленная ветка, а содержимое файла успешно прочитано.

![Потерянный коммит в reflog](assets/10_reflog.png)

![Восстановленный файл](assets/11_recovered_data.png)

### Revert

После добавления строки `BROKEN_CODE` выполнен `git revert`. В истории сохранились и вредный коммит, и отдельный коммит отмены; при этом ошибочная строка исчезла из файла.

![История с revert-коммитом](assets/12_revert_history.png)

![calculator.py после revert](assets/13_calculator_after_revert.png)

## Бонус. Git hook для Conventional Commits

В репозитории добавлен `commit-msg` hook. Он проверяет формат сообщения и принимает типы `feat`, `fix`, `docs`, `chore`, `refactor`, `merge`, `test`, `ci`, `build`, `perf` и `style`.

![Неверное сообщение заблокировано](assets/14_hook_blocked.png)

![Корректное сообщение принято](assets/15_hook_success.png)

## Вывод

В ходе работы были отработаны конфликты слияния, стратегии merge и rebase, очистка истории через interactive rebase, выборочный перенос изменений через cherry-pick, восстановление потерянного коммита с помощью reflog, безопасная отмена изменений через revert и контроль сообщений коммитов с помощью Git hook.

# Архив устаревших файлов

Эта папка содержит устаревшие файлы, которые были заменены на более актуальные версии.

## Структура архива

### scripts/ - Устаревшие PowerShell скрипты
- `gitsync-service-fixed.ps1` - Исправленная версия (заменена на working)
- `gitsync-service-script.ps1` - Базовая версия (заменена на working)
- `gitsync-service-test.ps1` - Тестовая версия (заменена на working)

### bat-files/ - Устаревшие bat файлы установки
- `create-service-powershell.bat` - Создание PowerShell службы
- `install-cmd-service.bat` - Установка CMD службы
- `install-cmd-wrapper-service.bat` - Установка CMD wrapper службы
- `install-fixed-service.bat` - Установка исправленной службы
- `install-gitsync-task.bat` - Установка задачи GitSync
- `install-powershell-service.bat` - Установка PowerShell службы
- `install-simple-task.bat` - Установка простой задачи
- `install-test-service.bat` - Установка тестовой службы
- `install-working-service.bat` - Установка рабочей службы
- `reinstall-gitsync-service.bat` - Переустановка службы GitSync
- `start-gitsync-service-admin.bat` - Запуск службы от администратора
- `start-service-admin.bat` - Запуск службы от администратора

### docs/ - Устаревшая документация
- `FINAL-REPORT-GitSync-Integration.md` - Итоговый отчет по интеграции

## Причина архивирования

Все эти файлы были заменены на финальные версии:
- **Актуальный скрипт службы**: `ci/scripts/gitsync-service-working.ps1`
- **Актуальный установщик**: `install-gitsync-service-final.ps1` и `install-gitsync-service-final.bat`
- **Актуальная документация**: `README.md`

## Восстановление

Если необходимо восстановить какой-либо файл из архива, просто скопируйте его обратно в основную папку проекта.

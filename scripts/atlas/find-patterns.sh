#!/bin/bash
# SourceAtlas - Pattern Detection Script (Ultra-Fast Version)
# Multi-Language Support: Swift/iOS, TypeScript/React, Android/Kotlin, and Python
#
# Purpose: Identify files matching a given pattern type using filename/directory matching only
# Philosophy: Scripts collect data quickly, AI does deep interpretation
#
# Ranking Algorithm (File/Dir Only - Ultra Fast):
#   - File name match: +10 points
#   - Directory name match: +8 points
#   - Skips content analysis (AI can read top files later)
#   - Skips recency check (too slow on large projects)
#   - Skips file size analysis (minimal value, high cost)
#
# Trade-offs:
#   + Blazing fast (<5s even on LARGE projects)
#   + Simple and reliable
#   + Good enough for pattern detection (80%+ accuracy)
#   - Misses files with non-standard names
#   - Can't rank by content relevance
#
# Usage: ./find-patterns.sh "pattern type" [project_path]
# Example: ./find-patterns.sh "api endpoint" ./my-project
#
# Performance Target: <5s on ALL project sizes

set -euo pipefail

PATTERN="${1:-}"
PROJECT_PATH="${2:-.}"

# Detect project type (swift vs typescript vs android vs python)
detect_project_type() {
    local path="$1"

    # Check for Android indicators (highest priority - most specific)
    if [ -f "$path/build.gradle" ] || [ -f "$path/build.gradle.kts" ] || \
       [ -f "$path/settings.gradle" ] || [ -f "$path/settings.gradle.kts" ] || \
       find "$path" -maxdepth 3 -name "AndroidManifest.xml" 2>/dev/null | grep -q .; then
        echo "android"
        return
    fi

    # Check for Swift/iOS indicators
    if [ -f "$path/Podfile" ] || [ -f "$path/Package.swift" ] || \
       find "$path" -maxdepth 3 -name "*.xcodeproj" -o -name "*.xcworkspace" 2>/dev/null | grep -q .; then
        echo "swift"
        return
    fi

    # Check for Python indicators (before TypeScript because Python projects often have package.json for frontend assets)
    if [ -f "$path/requirements.txt" ] || [ -f "$path/setup.py" ] || \
       [ -f "$path/pyproject.toml" ] || [ -f "$path/Pipfile" ] || \
       [ -f "$path/manage.py" ] || [ -f "$path/setup.cfg" ]; then
        echo "python"
        return
    fi

    # Check for TypeScript/JavaScript indicators
    if [ -f "$path/package.json" ] || [ -f "$path/tsconfig.json" ]; then
        echo "typescript"
        return
    fi

    # Default to swift for backward compatibility
    echo "swift"
}

PROJECT_TYPE=$(detect_project_type "$PROJECT_PATH")

# Normalize pattern (lowercase, trim)
normalize_pattern() {
    echo "$1" | tr '[:upper:]' '[:lower:]' | xargs
}

# Get file patterns for pattern based on project type
get_file_patterns() {
    local pattern="$1"
    local proj_type="$2"

    if [ "$proj_type" = "android" ]; then
        # Android/Kotlin patterns
        case "$pattern" in
            "viewmodel"|"view model"|"mvvm"|"presenter")
                echo "*ViewModel.kt *ViewModel.java *VM.kt *VM.java *Presenter.kt *Presenter.java"
                ;;
            "repository"|"repo")
                echo "*Repository.kt *Repository.java *Repo.kt *Repo.java *DataSource.kt *DataSource.java"
                ;;
            "composable"|"compose"|"jetpack compose"|"screen")
                echo "*Screen.kt *Composable.kt Ui*.kt *Component.kt"
                ;;
            "fragment")
                echo "*Fragment.kt *Fragment.java *Frag.kt *Frag.java"
                ;;
            "hilt"|"dagger"|"di"|"dependency injection")
                echo "*Module.kt *Module.java *Component.kt *Component.java AppModule.kt NetworkModule.kt DatabaseModule.kt Di*.kt Di*.java"
                ;;
            "usecase"|"use case"|"interactor")
                echo "*UseCase.kt *UseCase.java *Interactor.kt *Interactor.java Get*.kt Fetch*.kt Save*.kt"
                ;;
            "room"|"dao"|"database")
                echo "*Dao.kt *Dao.java *Entity.kt *Entity.java *Database.kt *Database.java *RoomDatabase.kt"
                ;;
            "retrofit"|"api"|"networking"|"network")
                echo "*ApiService.kt *ApiService.java *Api.kt *Api.java *Client.kt *Client.java *Interceptor.kt NetworkModule.kt"
                ;;
            "state"|"stateflow"|"livedata"|"state management"|"uistate")
                echo "*State.kt *State.java *UiState.kt *Event.kt *Action.kt *Intent.kt *Effect.kt"
                ;;
            "navigation"|"nav"|"navigator")
                echo "*Navigator.kt *Navigator.java *Coordinator.kt nav_graph.xml *Directions.kt"
                ;;
            "adapter"|"recyclerview"|"viewholder")
                echo "*Adapter.kt *Adapter.java *RecyclerAdapter.kt *ViewHolder.kt *ViewHolder.java *ListAdapter.kt"
                ;;
            "workmanager"|"worker"|"background")
                echo "*Worker.kt *Worker.java *WorkManager.kt *WorkRequest.kt"
                ;;
            "activity")
                echo "*Activity.kt *Activity.java MainActivity.kt"
                ;;
            "service")
                echo "*Service.kt *Service.java *ForegroundService.kt"
                ;;
            "receiver"|"broadcastreceiver"|"broadcast")
                echo "*Receiver.kt *Receiver.java *BroadcastReceiver.kt *BroadcastReceiver.java"
                ;;
            "mapper"|"converter")
                echo "*Mapper.kt *Mapper.java *Converter.kt *Converter.java *Transformer.kt"
                ;;
            "sealed"|"result"|"resource")
                echo "*Result.kt *Result.java *Response.kt *Resource.kt UiState.kt"
                ;;
            "extension"|"ext"|"extensions")
                echo "*Extensions.kt *Ext.kt *Extension.kt"
                ;;
            "viewbinding"|"databinding"|"binding")
                echo "*Binding.kt *Binding.java"
                ;;
            "singleton"|"object"|"manager")
                echo "*Manager.kt *Manager.java *Provider.kt *Singleton.kt AppConfig.kt"
                ;;
            "test"|"testing"|"mock"|"fake"|"stub")
                echo "*Test.kt *Test.java *Tests.kt *Tests.java Mock*.kt Mock*.java Fake*.kt Fake*.java *Mock.kt *Mock.java *Fake.kt *Fake.java *Stub.kt *Stub.java"
                ;;
            "store"|"redux"|"mvi store")
                echo "*Store.kt *Store.java *Redux.kt *Redux.java"
                ;;
            "factory"|"builder"|"creator")
                echo "*Factory.kt *Factory.java *Builder.kt *Builder.java *Creator.kt *Creator.java"
                ;;
            "provider"|"content provider")
                echo "*Provider.kt *Provider.java *ContentProvider.kt *ContentProvider.java"
                ;;
            "contract"|"interface"|"abstraction")
                echo "*Contract.kt *Contract.java"
                ;;
            "config"|"configuration"|"settings"|"preferences")
                echo "*Config.kt *Config.java *Configuration.kt *Configuration.java *Settings.kt *Settings.java *Preferences.kt *Preferences.java"
                ;;
            "validator"|"validation")
                echo "*Validator.kt *Validator.java *Validation.kt *Validation.java"
                ;;
            "parser"|"serializer"|"deserializer")
                echo "*Parser.kt *Parser.java *Serializer.kt *Serializer.java *Deserializer.kt *Deserializer.java"
                ;;
            "formatter"|"format")
                echo "*Formatter.kt *Formatter.java *Format.kt *Format.java"
                ;;
            "loader"|"fetcher")
                echo "*Loader.kt *Loader.java *Fetcher.kt *Fetcher.java"
                ;;
            "listener"|"callback"|"handler")
                echo "*Listener.kt *Listener.java *Callback.kt *Callback.java *Handler.kt *Handler.java"
                ;;
            *)
                echo ""
                ;;
        esac
    elif [ "$proj_type" = "python" ]; then
        # Python patterns
        case "$pattern" in
            # Tier 1 - Core Patterns (12)
            "model"|"models"|"orm"|"django model")
                echo "models.py *models.py *model.py *_models.py *_model.py"
                ;;
            "view"|"views"|"django view"|"endpoint")
                echo "views.py *views.py *view.py *_views.py *_view.py"
                ;;
            "serializer"|"serializers"|"schema"|"schemas"|"pydantic"|"marshmallow")
                echo "serializers.py *serializers.py *serializer.py *schemas.py *schema.py *_serializer.py *_schema.py"
                ;;
            "service"|"services"|"business logic")
                echo "*service.py *services.py *_service.py *_services.py"
                ;;
            "repository"|"repo"|"data access")
                echo "*repository.py *repositories.py *repo.py *_repository.py *_repo.py"
                ;;
            "api"|"router"|"routers"|"fastapi"|"flask"|"routes"|"urls"|"routing")
                echo "*api.py *router.py *routers.py *routes.py *routing.py urls.py *_api.py *_router.py *_routes.py"
                ;;
            "form"|"forms"|"django form")
                echo "forms.py *forms.py *form.py *_forms.py *_form.py"
                ;;
            "task"|"tasks"|"celery"|"background job"|"worker"|"workers")
                echo "tasks.py *tasks.py *task.py celery.py *celery.py *worker.py *workers.py *_task.py *_tasks.py"
                ;;
            "test"|"tests"|"pytest"|"unittest"|"testing")
                echo "test_*.py *_test.py tests.py *tests.py conftest.py"
                ;;
            "admin"|"django admin")
                echo "admin.py *admin.py *_admin.py"
                ;;
            "middleware"|"middlewares")
                echo "middleware.py *middleware.py *middlewares.py *_middleware.py"
                ;;
            "config"|"settings"|"configuration"|"conf")
                echo "config.py *config.py settings.py *settings.py *conf.py *_config.py *_settings.py"
                ;;

            # Tier 2 - Supplementary Patterns (12)
            "migration"|"migrations"|"alembic")
                echo "*migrations*.py versions/*.py"
                ;;
            "command"|"commands"|"management command"|"cli")
                echo "*command.py *commands.py"
                ;;
            "util"|"utils"|"helpers"|"helper")
                echo "utils.py *utils.py util.py *util.py helpers.py *helpers.py helper.py *helper.py *_utils.py *_helpers.py"
                ;;
            "exception"|"exceptions"|"errors"|"error handling")
                echo "exceptions.py *exceptions.py *exception.py errors.py *errors.py *_exceptions.py *_errors.py"
                ;;
            "validator"|"validators"|"validation")
                echo "validators.py *validators.py *validator.py validation.py *validation.py *_validators.py"
                ;;
            "factory"|"factories"|"factory boy")
                echo "*factory.py *factories.py *_factory.py *_factories.py"
                ;;
            "fixture"|"fixtures"|"test data")
                echo "*fixtures.py fixtures.py conftest.py"
                ;;
            "signal"|"signals"|"django signal")
                echo "signals.py *signals.py *signal.py *_signals.py"
                ;;
            "manager"|"managers"|"django manager")
                echo "*manager.py *managers.py *_manager.py *_managers.py"
                ;;
            "mixin"|"mixins")
                echo "*mixin.py *mixins.py *_mixin.py *_mixins.py"
                ;;
            "decorator"|"decorators")
                echo "*decorator.py *decorators.py *_decorator.py *_decorators.py"
                ;;
            "client"|"clients"|"http client"|"api client")
                echo "*client.py *clients.py *_client.py *_clients.py"
                ;;
            "pipeline"|"pipelines"|"scrapy pipeline")
                echo "*pipeline.py *pipelines.py *_pipeline.py *_pipelines.py"
                ;;
            "spider"|"spiders"|"scrapy"|"crawler")
                echo "*spider.py *spiders.py *_spider.py *_spiders.py"
                ;;
            *)
                echo ""
                ;;
        esac
    elif [ "$proj_type" = "typescript" ]; then
        # TypeScript/React/Vue patterns
        case "$pattern" in
            # Tier 1 - Core Patterns (10 original + 8 new React + 7 Vue = 25)
            "react component"|"component")
                echo "*.tsx *Component.tsx *component.tsx"
                ;;
            "react hook"|"hook"|"hooks"|"custom hook")
                echo "use*.ts use*.tsx *hook.ts *hooks.ts"
                ;;
            "state management"|"store"|"state"|"zustand"|"redux")
                echo "*store.ts *slice.ts *reducer.ts *context.tsx *provider.tsx *state.ts *Store.ts"
                ;;
            "api endpoint"|"api"|"endpoint"|"trpc")
                echo "*route.ts *route.tsx *api.ts *api.tsx *controller.ts *service.ts *endpoint.ts *handler.ts *.api.ts *router.ts"
                ;;
            "authentication"|"auth"|"login")
                echo "*auth.ts *auth.tsx *session.ts *login.ts *credential.ts *jwt.ts"
                ;;
            "form handling"|"form"|"forms"|"react hook form"|"zod")
                echo "*form.tsx *form.ts *validation.ts *schema.ts"
                ;;
            "database query"|"database"|"query"|"prisma")
                echo "*repository.ts *model.ts *entity.ts *schema.ts *query.ts *dao.ts schema.prisma"
                ;;
            "networking"|"network"|"http client"|"fetch"|"axios")
                echo "*client.ts *http.ts *fetch.ts *api.ts *request.ts *axios.ts"
                ;;
            "nextjs page"|"page")
                echo "page.tsx page.ts"
                ;;
            "nextjs layout"|"layout")
                echo "layout.tsx layout.ts"
                ;;

            # New React Tier 1 Patterns (8)
            "react query"|"tanstack query"|"data fetching"|"swr")
                echo "*Query.ts *Queries.ts *query.ts use*Query.ts use*Query.tsx *fetcher.ts"
                ;;
            "react context"|"context api")
                echo "*Context.tsx *Context.ts *context.tsx *context.ts"
                ;;
            "hoc"|"higher order component")
                echo "with*.tsx with*.ts *HOC.tsx *HOC.ts *hoc.tsx *hoc.ts"
                ;;
            "error boundary"|"boundary")
                echo "*ErrorBoundary.tsx *Boundary.tsx *boundary.tsx error.tsx"
                ;;
            "suspense"|"fallback")
                echo "*Suspense.tsx *suspense.tsx *Fallback.tsx *fallback.tsx loading.tsx"
                ;;
            "portal"|"modal"|"dialog")
                echo "*Portal.tsx *portal.tsx *Modal.tsx *modal.tsx *Dialog.tsx *dialog.tsx"
                ;;
            "ref"|"forward ref"|"imperative handle")
                echo "*Ref.ts *ref.ts use*Ref.ts"
                ;;
            "memo"|"memoization"|"performance")
                echo "*memo.ts *Memo.tsx useMemo*.ts useCallback*.ts"
                ;;

            # Vue Tier 1 Patterns (7)
            "vue component"|"sfc"|"vue")
                echo "*.vue"
                ;;
            "composable"|"composition"|"vue hook")
                echo "use*.ts"
                ;;
            "pinia"|"pinia store"|"vue store")
                echo "*Store.ts *store.ts use*Store.ts"
                ;;
            "vue router"|"vue routes"|"router")
                echo "router.ts *router.ts *Routes.ts routes.ts"
                ;;
            "directive"|"directives"|"vue directive")
                echo "*Directive.ts *directive.ts v-*.ts"
                ;;
            "vue plugin"|"plugin"|"plugins")
                echo "*Plugin.ts *plugin.ts"
                ;;
            "provide"|"inject"|"provide inject")
                echo "*Provider.vue *Injection.ts *injection.ts provide*.ts inject*.ts"
                ;;

            # Tier 2 - Supplementary Patterns (12 original + 6 React + 5 Vue = 23)
            "nextjs middleware"|"middleware")
                echo "middleware.ts middleware.tsx"
                ;;
            "nextjs loading"|"loading")
                echo "loading.tsx loading.ts"
                ;;
            "nextjs error"|"error")
                echo "error.tsx error.ts"
                ;;
            "background job"|"job"|"queue"|"worker")
                echo "*worker.ts *job.ts *task.ts *queue.ts *processor.ts *cron.ts"
                ;;
            "file upload"|"upload"|"file storage"|"storage")
                echo "*upload.ts *upload.tsx *storage.ts *file.ts *media.ts"
                ;;
            "test"|"testing"|"mock"|"e2e"|"unit test"|"vitest"|"jest")
                echo "*.test.ts *.test.tsx *.spec.ts *.spec.tsx *mock.ts *Mock.ts mock*.ts *.test.vue"
                ;;
            "theme"|"style"|"styling"|"design system"|"tailwind")
                echo "*theme.ts *theme.tsx *styles.ts *styled.ts *design.ts *tokens.ts tailwind.config.*"
                ;;
            "server component"|"rsc"|"server")
                echo "*.server.tsx *.server.ts"
                ;;
            "server action"|"action"|"actions")
                echo "*action.ts *actions.ts server-action.ts"
                ;;
            "context"|"context provider"|"provider")
                echo "*Context.tsx *context.tsx *Provider.tsx *provider.tsx"
                ;;
            "types"|"type"|"interface"|"interfaces"|"typescript")
                echo "*types.ts *type.ts *interface.ts *.d.ts"
                ;;
            "config"|"configuration"|"environment"|"env")
                echo "*config.ts *configuration.ts *env.ts *.config.ts *.config.js *.config.mjs"
                ;;

            # New React Tier 2 Patterns (6)
            "storybook"|"stories"|"story")
                echo "*.stories.tsx *.stories.ts *.stories.mdx"
                ;;
            "animation"|"framer"|"motion"|"transition")
                echo "*Animation.tsx *animation.tsx *Motion.tsx *motion.tsx *transition.tsx *Transition.tsx"
                ;;
            "i18n"|"translation"|"locale"|"intl")
                echo "*i18n.ts *locale.ts *translation.ts *intl.ts locales/*.json messages/*.json"
                ;;
            "graphql"|"apollo"|"urql"|"gql")
                echo "*.graphql *.gql *Query.graphql *Mutation.graphql *Fragment.graphql"
                ;;
            "rtk query"|"redux toolkit"|"rtk"|"createapi")
                echo "*Api.ts *api.ts *Slice.ts *slice.ts"
                ;;
            "react router"|"routing"|"routes")
                echo "*Routes.tsx *Router.tsx *routes.tsx *router.tsx routes/*.tsx"
                ;;

            # Vue Tier 2 Patterns (5)
            "nuxt page"|"nuxt pages")
                echo "pages/*.vue pages/**/*.vue"
                ;;
            "nuxt layout"|"nuxt layouts")
                echo "layouts/*.vue"
                ;;
            "nuxt middleware"|"nuxt middlewares")
                echo "middleware/*.ts middleware/*.js"
                ;;
            "nuxt plugin"|"nuxt plugins")
                echo "plugins/*.ts plugins/*.js"
                ;;
            "vueuse"|"vue composable library")
                echo "use*.ts composables/use*.ts"
                ;;
            *)
                echo ""
                ;;
        esac
    else
        # Swift/iOS patterns
        case "$pattern" in
            # Tier 1 - Core Patterns (14)
            "protocol"|"delegate"|"protocol delegate")
                echo "*Delegate.swift *Delegate.m *Delegate.h *DataSource.swift *DataSource.m *DataSource.h *Protocol.swift *Protocol.m *Protocol.h"
                ;;
            "combine"|"publisher"|"combine publisher")
                echo "*Publisher.swift *Publisher.m *Publisher.h *Subject.swift *Subject.m *Subject.h *Subscription.swift *Subscription.m *Subscription.h *Combine*.swift *Combine*.m *Combine*.h"
                ;;
            "async"|"await"|"async await"|"concurrency")
                echo "*Async*.swift *Async*.m *Async*.h *Task*.swift *Task*.m *Task*.h *Actor*.swift *Actor*.m *Actor*.h"
                ;;
            "repository"|"repo"|"database"|"query"|"database query")
                echo "*Repository.swift *Repository.m *Repository.h *DAO.swift *DAO.m *DAO.h *Store.swift *Store.m *Store.h *DataSource.swift *DataSource.m *DataSource.h *Query.swift *Query.m *Query.h *Model.swift *Model.m *Model.h *Database*.swift *Database*.m *Database*.h *Entity*.swift *Entity*.m *Entity*.h"
                ;;
            "service"|"service layer"|"manager"|"networking"|"network")
                echo "*Service.swift *Service.m *Service.h *Manager.swift *Manager.m *Manager.h *Provider.swift *Provider.m *Provider.h *Client.swift *Client.m *Client.h *Network*.swift *Network*.m *Network*.h *API*.swift *API*.m *API*.h *Request*.swift *Request*.m *Request*.h *HTTPClient*.swift *HTTPClient*.m *HTTPClient*.h"
                ;;
            "usecase"|"use case"|"interactor")
                echo "*UseCase.swift *UseCase.m *UseCase.h *Interactor.swift *Interactor.m *Interactor.h *Command.swift *Command.m *Command.h"
                ;;
            "router"|"route"|"routing"|"api endpoint"|"api"|"endpoint")
                echo "*Router.swift *Router.m *Router.h *Route.swift *Route.m *Route.h *URLRouter.swift *URLRouter.m *URLRouter.h *Endpoint.swift *Endpoint.m *Endpoint.h *Controller.swift *Controller.m *Controller.h *API.swift *API.m *API.h routes.*"
                ;;
            "factory"|"builder"|"dependency injection"|"di"|"injection")
                echo "*Factory.swift *Factory.m *Factory.h *Builder.swift *Builder.m *Builder.h *Creator.swift *Creator.m *Creator.h *DIContainer.swift *DIContainer.m *DIContainer.h *Injector.swift *Injector.m *Injector.h *Container.swift *Container.m *Container.h *Dependencies.swift *Dependencies.m *Dependencies.h *DI*.swift *DI*.m *DI*.h *Assembly.swift *Assembly.m *Assembly.h"
                ;;
            "viewmodel"|"view model"|"mvvm"|"observable"|"observableobject"|"observable object")
                echo "*ViewModel.swift *ViewModel.m *ViewModel.h *VM.swift *VM.m *VM.h *Store.swift *Store.m *Store.h"
                ;;
            "view controller"|"viewcontroller")
                echo "*ViewController.swift *ViewController.m *ViewController.h *VC.swift *VC.m *VC.h *Controller.swift *Controller.m *Controller.h"
                ;;
            "swiftui view"|"view")
                echo "*View.swift *Screen.swift *Page.swift"
                ;;
            "coordinator"|"navigation coordinator")
                echo "*Coordinator.swift *Coordinator.m *Coordinator.h *Navigation*.swift *Navigation*.m *Navigation*.h *Flow*.swift *Flow*.m *Flow*.h"
                ;;
            "core data"|"coredata"|"persistence"|"data persistence")
                echo "*.xcdatamodeld *+CoreDataProperties.swift *+CoreDataProperties.m *+CoreDataProperties.h *+CoreDataClass.swift *+CoreDataClass.m *+CoreDataClass.h *ManagedObject*.swift *ManagedObject*.m *ManagedObject*.h *CoreData*.swift *CoreData*.m *CoreData*.h"
                ;;
            "layout"|"collection view layout"|"uicollectionviewlayout")
                echo "*Layout.swift *Layout.m *Layout.h *FlowLayout.swift *FlowLayout.m *FlowLayout.h *CollectionViewLayout.swift *CollectionViewLayout.m *CollectionViewLayout.h"
                ;;

            # Tier 2 - Supplementary Patterns (15)
            "reducer"|"tca reducer"|"state reducer")
                echo "*Reducer.swift *Reducer.m *Reducer.h *Action.swift *Action.m *Action.h *State.swift *State.m *State.h *Domain.swift *Domain.m *Domain.h"
                ;;
            "environment"|"configuration"|"config")
                echo "*Environment.swift *Environment.m *Environment.h *Config.swift *Config.m *Config.h *Configuration.swift *Configuration.m *Configuration.h"
                ;;
            "cache"|"caching")
                echo "*Cache.swift *Cache.m *Cache.h *CacheManager.swift *CacheManager.m *CacheManager.h *ImageCache.swift *ImageCache.m *ImageCache.h"
                ;;
            "theme"|"style"|"appearance")
                echo "*Theme.swift *Theme.m *Theme.h *Style.swift *Style.m *Style.h *Appearance.swift *Appearance.m *Appearance.h"
                ;;
            "mock"|"stub"|"fake"|"test double")
                echo "Mock*.swift Mock*.m Mock*.h *Mock.swift *Mock.m *Mock.h *Stub.swift *Stub.m *Stub.h Fake*.swift Fake*.m Fake*.h"
                ;;
            "middleware"|"interceptor")
                echo "*Middleware.swift *Middleware.m *Middleware.h *Interceptor.swift *Interceptor.m *Interceptor.h"
                ;;
            "localization"|"i18n"|"l10n")
                echo "Localizable.swift Localizable.m Localizable.h *Localization.swift *Localization.m *Localization.h *.strings"
                ;;
            "animation"|"animator"|"transition")
                echo "*Animation.swift *Animation.m *Animation.h *Animator.swift *Animator.m *Animator.h *Transition.swift *Transition.m *Transition.h"
                ;;
            "authentication"|"auth"|"login")
                echo "*Auth*.swift *Auth*.m *Auth*.h *Session*.swift *Session*.m *Session*.h *Login*.swift *Login*.m *Login*.h *Credential*.swift *Credential*.m *Credential*.h *Token*.swift *Token*.m *Token*.h *Security*.swift *Security*.m *Security*.h"
                ;;
            "background job"|"job"|"queue")
                echo "*Job.swift *Job.m *Job.h *Worker.swift *Worker.m *Worker.h *Task.swift *Task.m *Task.h *Queue*.swift *Queue*.m *Queue*.h *Operation*.swift *Operation*.m *Operation*.h *Async*.swift *Async*.m *Async*.h"
                ;;
            "file upload"|"upload"|"file storage")
                echo "*Upload*.swift *Upload*.m *Upload*.h *Storage*.swift *Storage*.m *Storage*.h *File*.swift *File*.m *File*.h *Media*.swift *Media*.m *Media*.h *Image*.swift *Image*.m *Image*.h *Attachment*.swift *Attachment*.m *Attachment*.h"
                ;;
            "table view cell"|"collection view cell"|"cell"|"cells")
                echo "*Cell.swift *Cell.m *Cell.h *TableViewCell.swift *TableViewCell.m *TableViewCell.h *CollectionViewCell.swift *CollectionViewCell.m *CollectionViewCell.h"
                ;;
            "extension"|"extensions")
                echo "*+*.swift *+*.m *+*.h *Extension*.swift *Extension*.m *Extension*.h"
                ;;
            "view modifier"|"viewmodifier"|"swiftui modifier"|"modifier")
                echo "*Modifier.swift *ViewModifier.swift"
                ;;
            "error handling"|"error"|"errors")
                echo "*Error.swift *Error.m *Error.h *ErrorHandler.swift *ErrorHandler.m *ErrorHandler.h *Result.swift *Result.m *Result.h *Failure.swift *Failure.m *Failure.h"
                ;;
            *)
                echo ""
                ;;
        esac
    fi
}

# Get directory patterns for pattern based on project type
get_dir_patterns() {
    local pattern="$1"
    local proj_type="$2"

    if [ "$proj_type" = "android" ]; then
        # Android/Kotlin directory patterns
        case "$pattern" in
            "viewmodel"|"view model"|"mvvm"|"presenter")
                echo "viewmodel viewmodels presentation ui/*/viewmodel presenter"
                ;;
            "repository"|"repo")
                echo "repository repositories data/repository data/source"
                ;;
            "composable"|"compose"|"jetpack compose"|"screen")
                echo "compose ui/compose ui/screen screens components ui/components"
                ;;
            "fragment")
                echo "fragment fragments ui/fragment ui/*/fragment"
                ;;
            "hilt"|"dagger"|"di"|"dependency injection")
                echo "di injection dagger hilt modules"
                ;;
            "usecase"|"use case"|"interactor")
                echo "usecase usecases domain/usecase domain/interactor interactors"
                ;;
            "room"|"dao"|"database")
                echo "database db data/local data/db room dao entity"
                ;;
            "retrofit"|"api"|"networking"|"network")
                echo "network api remote data/remote service"
                ;;
            "state"|"stateflow"|"livedata"|"state management"|"uistate")
                echo "state states ui/state event mvi"
                ;;
            "navigation"|"nav"|"navigator")
                echo "navigation nav coordinator"
                ;;
            "adapter"|"recyclerview"|"viewholder")
                echo "adapter adapters ui/adapter recyclerview"
                ;;
            "workmanager"|"worker"|"background")
                echo "worker workers work background"
                ;;
            "activity")
                echo "activity activities ui/activity"
                ;;
            "service")
                echo "service services background"
                ;;
            "receiver"|"broadcastreceiver"|"broadcast")
                echo "receiver receivers broadcast"
                ;;
            "mapper"|"converter")
                echo "mapper mappers converter util/mapper"
                ;;
            "sealed"|"result"|"resource")
                echo "model data/model common"
                ;;
            "extension"|"ext"|"extensions")
                echo "extension extensions ext util/ext"
                ;;
            "viewbinding"|"databinding"|"binding")
                echo "ui layout"
                ;;
            "singleton"|"object"|"manager")
                echo "manager singleton util"
                ;;
            "test"|"testing"|"mock"|"fake"|"stub")
                echo "test tests testing mock mocks fake fakes stub stubs androidTest testFixtures"
                ;;
            "store"|"redux"|"mvi store")
                echo "store stores state redux mvi"
                ;;
            "factory"|"builder"|"creator")
                echo "factory factories builder builders di"
                ;;
            "provider"|"content provider")
                echo "provider providers content"
                ;;
            "contract"|"interface"|"abstraction")
                echo "contract contracts interface interfaces"
                ;;
            "config"|"configuration"|"settings"|"preferences")
                echo "config configuration settings preferences"
                ;;
            "validator"|"validation")
                echo "validator validators validation"
                ;;
            "parser"|"serializer"|"deserializer")
                echo "parser parsers serializer serializers"
                ;;
            "formatter"|"format")
                echo "formatter formatters format"
                ;;
            "loader"|"fetcher")
                echo "loader loaders fetcher"
                ;;
            "listener"|"callback"|"handler")
                echo "listener listeners callback callbacks handler handlers"
                ;;
            *)
                echo ""
                ;;
        esac
    elif [ "$proj_type" = "python" ]; then
        # Python directory patterns
        case "$pattern" in
            # Tier 1 - Core Patterns (12)
            "model"|"models"|"orm"|"django model")
                echo "models domain entities"
                ;;
            "view"|"views"|"django view"|"endpoint")
                echo "views api endpoints"
                ;;
            "serializer"|"serializers"|"schema"|"schemas"|"pydantic"|"marshmallow")
                echo "serializers schemas"
                ;;
            "service"|"services"|"business logic")
                echo "services service domain"
                ;;
            "repository"|"repo"|"data access")
                echo "repositories repository repos"
                ;;
            "api"|"router"|"routers"|"fastapi"|"flask"|"routes"|"urls")
                echo "api routers routes endpoints"
                ;;
            "form"|"forms"|"django form")
                echo "forms"
                ;;
            "task"|"tasks"|"celery"|"background job"|"worker"|"workers")
                echo "tasks workers jobs celery"
                ;;
            "test"|"tests"|"pytest"|"unittest"|"testing")
                echo "tests test testing"
                ;;
            "admin"|"django admin")
                echo "admin"
                ;;
            "middleware"|"middlewares")
                echo "middleware middlewares"
                ;;
            "config"|"settings"|"configuration"|"conf")
                echo "config settings conf configuration"
                ;;

            # Tier 2 - Supplementary Patterns (12)
            "migration"|"migrations"|"alembic")
                echo "migrations alembic versions"
                ;;
            "command"|"commands"|"management command"|"cli")
                echo "commands management management/commands"
                ;;
            "util"|"utils"|"helpers"|"helper")
                echo "utils util helpers common lib"
                ;;
            "exception"|"exceptions"|"errors"|"error handling")
                echo "exceptions errors"
                ;;
            "validator"|"validators"|"validation")
                echo "validators validation"
                ;;
            "factory"|"factories"|"factory boy")
                echo "factories"
                ;;
            "fixture"|"fixtures"|"test data")
                echo "fixtures"
                ;;
            "signal"|"signals"|"django signal")
                echo "signals"
                ;;
            "manager"|"managers"|"django manager")
                echo "managers"
                ;;
            "mixin"|"mixins")
                echo "mixins"
                ;;
            "decorator"|"decorators")
                echo "decorators"
                ;;
            "client"|"clients"|"http client"|"api client")
                echo "clients client"
                ;;
            "pipeline"|"pipelines"|"scrapy pipeline")
                echo "pipelines"
                ;;
            "spider"|"spiders"|"scrapy"|"crawler")
                echo "spiders crawlers"
                ;;
            *)
                echo ""
                ;;
        esac
    elif [ "$proj_type" = "typescript" ]; then
        # TypeScript/React/Vue directory patterns
        case "$pattern" in
            # ==== REACT TIER 1 - Core Patterns (18) ====
            "react component"|"component")
                echo "components ui features modules views pages screens src/components src/ui"
                ;;
            "react hook"|"hook"|"hooks")
                echo "hooks composables utils lib src/hooks"
                ;;
            "state management"|"store"|"state"|"zustand"|"redux"|"jotai"|"recoil")
                echo "store stores state redux context providers slices atoms src/store src/stores"
                ;;
            "api endpoint"|"api"|"endpoint")
                echo "api routes controllers handlers services app/api pages/api src/api"
                ;;
            "authentication"|"auth"|"login")
                echo "auth authentication session security middleware src/auth"
                ;;
            "form handling"|"form"|"forms")
                echo "forms components ui features src/forms"
                ;;
            "database query"|"database"|"query"|"prisma"|"drizzle")
                echo "models entities repositories db database prisma schema drizzle src/db"
                ;;
            "networking"|"network"|"http client"|"fetcher")
                echo "api lib services utils http client fetchers src/lib"
                ;;
            "nextjs page"|"page"|"pages")
                echo "app src/app pages src/pages"
                ;;
            "nextjs layout"|"layout"|"layouts")
                echo "app src/app layouts src/layouts"
                ;;
            # New React Tier 1
            "react query"|"tanstack query"|"data fetching"|"swr")
                echo "queries hooks api lib services src/queries"
                ;;
            "react context"|"context api"|"context")
                echo "context contexts providers state src/context src/contexts"
                ;;
            "hoc"|"higher order component")
                echo "hoc hocs components lib utils"
                ;;
            "error boundary"|"error")
                echo "components errors boundaries app src/app src/components"
                ;;
            "suspense"|"lazy"|"loading")
                echo "components app src/app loading"
                ;;
            "portal"|"modal"|"dialog")
                echo "components portals modals dialogs ui src/components"
                ;;
            "ref"|"refs"|"forward ref"|"imperative handle")
                echo "components hooks lib utils"
                ;;
            "render props"|"render prop")
                echo "components lib utils features"
                ;;

            # ==== VUE TIER 1 - Core Patterns (7) ====
            "vue component"|"sfc"|"vue")
                echo "components views pages ui features src/components src/views"
                ;;
            "composable"|"composition"|"vue hook")
                echo "composables hooks utils lib src/composables use core shared"
                ;;
            "pinia"|"pinia store"|"vue store")
                echo "stores store pinia state src/stores"
                ;;
            "vue directive"|"directive"|"directives")
                echo "directives src/directives plugins"
                ;;
            "vue plugin"|"plugin"|"plugins")
                echo "plugins modules src/plugins"
                ;;
            "provide inject"|"provide"|"inject")
                echo "providers context injection composables"
                ;;
            "nuxt page"|"nuxt")
                echo "pages app src/pages"
                ;;

            # ==== REACT TIER 2 - Supplementary (12) ====
            "nextjs middleware"|"middleware")
                echo "middleware app src"
                ;;
            "nextjs loading"|"loading")
                echo "app src/app loading"
                ;;
            "background job"|"job"|"queue"|"worker")
                echo "jobs workers tasks queue background cron"
                ;;
            "file upload"|"upload"|"file storage"|"storage")
                echo "upload storage media files lib"
                ;;
            "test"|"testing"|"mock"|"e2e"|"unit test")
                echo "__tests__ tests test __mocks__ mocks e2e spec cypress playwright vitest"
                ;;
            "theme"|"style"|"styling"|"design system")
                echo "theme themes styles design tokens constants src/theme src/styles"
                ;;
            "server component"|"rsc"|"server")
                echo "app src/app components server"
                ;;
            "server action"|"action"|"actions")
                echo "actions app/actions lib/actions server"
                ;;
            "types"|"type"|"interface"|"interfaces")
                echo "types @types interfaces models lib src/types"
                ;;
            "config"|"configuration"|"environment"|"env")
                echo "config configuration env lib constants src/config"
                ;;
            "animation"|"motion"|"framer"|"spring")
                echo "animations motion framer components ui"
                ;;
            "i18n"|"internationalization"|"localization"|"locale")
                echo "i18n locales translations messages lang src/i18n"
                ;;
            "validation"|"schema"|"zod"|"yup")
                echo "schemas validations validators lib utils"
                ;;
            "trpc"|"rpc"|"type safe api")
                echo "trpc server routers procedures api"
                ;;

            # ==== VUE TIER 2 - Supplementary (11) ====
            "nuxt layout"|"nuxt layouts")
                echo "layouts src/layouts"
                ;;
            "nuxt middleware"|"nuxt route middleware")
                echo "middleware src/middleware"
                ;;
            "nuxt plugin"|"nuxt plugins")
                echo "plugins src/plugins"
                ;;
            "nuxt composable"|"nuxt composables")
                echo "composables src/composables"
                ;;
            "vue transition"|"transition"|"transitions")
                echo "components transitions animations"
                ;;
            "vue mixin"|"mixin"|"mixins")
                echo "mixins src/mixins lib"
                ;;
            "vue filter"|"filter"|"filters")
                echo "filters src/filters lib"
                ;;
            "vue test"|"vue testing"|"vue unit test")
                echo "__tests__ tests test spec vitest cypress"
                ;;
            "vue i18n"|"vue-i18n")
                echo "i18n locales lang translations messages"
                ;;
            "vue router"|"router guard"|"navigation guard")
                echo "router guards routes navigation src/router"
                ;;
            "vue module"|"modules")
                echo "modules src/modules features"
                ;;
            *)
                echo ""
                ;;
        esac
    else
        # Swift/iOS directory patterns
        case "$pattern" in
            # Tier 1 - Core Patterns (14)
            "protocol"|"delegate"|"protocol delegate")
                echo "Protocols Delegates Protocol/Delegates Domain/Protocols"
                ;;
            "combine"|"publisher"|"combine publisher")
                echo "Publishers Reactive Combine Streams Domain/Publishers"
                ;;
            "async"|"await"|"async await"|"concurrency")
                echo "Async Concurrency Tasks Actors Domain/Async"
                ;;
            "repository"|"repo"|"database"|"query"|"database query")
                echo "Repositories Data/Repositories DataLayer Domain/Repositories Data models queries stores database entities persistence"
                ;;
            "service"|"service layer"|"manager"|"networking"|"network")
                echo "Services Managers Business Domain/Services Application Networking Network API Client HTTP"
                ;;
            "usecase"|"use case"|"interactor")
                echo "UseCases Domain/UseCases Interactors Domain/Interactors Application/UseCases"
                ;;
            "router"|"route"|"routing"|"api endpoint"|"api"|"endpoint")
                echo "Routers Routing Navigation API/Routers Networking/Routers controllers routes api services networking"
                ;;
            "factory"|"builder"|"dependency injection"|"di"|"injection")
                echo "Factories Builders DI/Factories Domain/Factories Utilities/Factories DI DependencyInjection Dependencies Injection Factory Container"
                ;;
            "viewmodel"|"view model"|"mvvm"|"observable"|"observableobject"|"observable object")
                echo "ViewModels ViewModel MVVM Presentation Store State"
                ;;
            "view controller"|"viewcontroller")
                echo "ViewControllers Controllers UI Views"
                ;;
            "swiftui view"|"view")
                echo "Views Screens Pages UI Components"
                ;;
            "coordinator"|"navigation coordinator")
                echo "Coordinators Navigation Flow Routing"
                ;;
            "core data"|"coredata"|"persistence"|"data persistence")
                echo "CoreData Persistence Models Data Storage Database"
                ;;
            "layout"|"collection view layout"|"uicollectionviewlayout")
                echo "Layouts CustomLayouts UI/Layouts Views/Layouts CollectionViewLayouts"
                ;;

            # Tier 2 - Supplementary Patterns (15)
            "reducer"|"tca reducer"|"state reducer")
                echo "Reducers Store Features State TCA"
                ;;
            "environment"|"configuration"|"config")
                echo "Configuration Config Environment Settings"
                ;;
            "cache"|"caching")
                echo "Cache Storage Caching Data/Cache"
                ;;
            "theme"|"style"|"appearance")
                echo "Theme Themes Styles Appearance UI/Theme"
                ;;
            "mock"|"stub"|"fake"|"test double")
                echo "Mocks Testing Stubs Fakes Tests/Mocks"
                ;;
            "middleware"|"interceptor")
                echo "Middleware Interceptors Networking/Middleware"
                ;;
            "localization"|"i18n"|"l10n")
                echo "Localization Resources Locale *.lproj"
                ;;
            "animation"|"animator"|"transition")
                echo "Animations Transitions Animators UI/Animations Views/Animations"
                ;;
            "authentication"|"auth"|"login")
                echo "auth authentication session security credentials login"
                ;;
            "background job"|"job"|"queue")
                echo "jobs workers tasks operations background"
                ;;
            "file upload"|"upload"|"file storage")
                echo "uploads storage media files documents attachments"
                ;;
            "table view cell"|"collection view cell"|"cell"|"cells")
                echo "Cells TableViewCells CollectionViewCells Views/Cells UI/Cells"
                ;;
            "extension"|"extensions")
                echo "Extensions Utils Utilities Helpers Categories"
                ;;
            "view modifier"|"viewmodifier"|"swiftui modifier"|"modifier")
                echo "Modifiers ViewModifiers Extensions/ViewModifiers Views/Modifiers"
                ;;
            "error handling"|"error"|"errors")
                echo "Errors ErrorHandling Models/Errors Domain/Errors"
                ;;
            *)
                echo ""
                ;;
        esac
    fi
}

# Main execution
main() {
    if [ -z "$PATTERN" ]; then
        echo "Usage: $0 \"pattern type\" [project_path]" >&2
        echo "" >&2
        echo "Project type detected: $PROJECT_TYPE" >&2
        echo "" >&2
        if [ "$PROJECT_TYPE" = "android" ]; then
            echo "Supported patterns (Android/Kotlin):" >&2
            echo "" >&2
            echo "Tier 1 patterns:" >&2
            echo "  - viewmodel / view model / mvvm / presenter" >&2
            echo "  - repository / repo" >&2
            echo "  - composable / compose / jetpack compose / screen" >&2
            echo "  - fragment" >&2
            echo "  - hilt / dagger / di / dependency injection" >&2
            echo "  - usecase / use case / interactor" >&2
            echo "  - room / dao / database" >&2
            echo "  - retrofit / api / networking / network" >&2
            echo "  - state / stateflow / livedata / state management / uistate" >&2
            echo "  - navigation / nav / navigator" >&2
            echo "  - adapter / recyclerview / viewholder" >&2
            echo "  - workmanager / worker / background" >&2
            echo "" >&2
            echo "Tier 2 patterns:" >&2
            echo "  - activity" >&2
            echo "  - service" >&2
            echo "  - receiver / broadcastreceiver / broadcast" >&2
            echo "  - mapper / converter" >&2
            echo "  - sealed / result / resource" >&2
            echo "  - extension / ext / extensions" >&2
            echo "  - viewbinding / databinding / binding" >&2
            echo "  - singleton / object / manager" >&2
            echo "  - test / testing / mock / fake / stub" >&2
            echo "  - store / redux / mvi store" >&2
            echo "  - factory / builder / creator" >&2
            echo "  - provider / content provider" >&2
            echo "  - contract / interface / abstraction" >&2
            echo "  - config / configuration / settings / preferences" >&2
            echo "  - validator / validation" >&2
            echo "  - parser / serializer / deserializer" >&2
            echo "  - formatter / format" >&2
            echo "  - loader / fetcher" >&2
            echo "  - listener / callback / handler" >&2
        elif [ "$PROJECT_TYPE" = "typescript" ]; then
            echo "Supported patterns (TypeScript/React/Vue/Next.js/Nuxt):" >&2
            echo "" >&2
            echo "=== React Tier 1 (18 patterns) ===" >&2
            echo "  - react component / component" >&2
            echo "  - react hook / hook / hooks / custom hook" >&2
            echo "  - state management / store / state / zustand / redux" >&2
            echo "  - api endpoint / api / endpoint / trpc" >&2
            echo "  - authentication / auth / login" >&2
            echo "  - form handling / form / forms / react hook form / zod" >&2
            echo "  - database query / database / query / prisma" >&2
            echo "  - networking / network / http client / fetch / axios" >&2
            echo "  - nextjs page / page" >&2
            echo "  - nextjs layout / layout" >&2
            echo "  - react query / tanstack query / data fetching / swr" >&2
            echo "  - react context / context api" >&2
            echo "  - hoc / higher order component" >&2
            echo "  - error boundary / boundary" >&2
            echo "  - suspense / fallback" >&2
            echo "  - portal / modal / dialog" >&2
            echo "  - ref / forward ref / imperative handle" >&2
            echo "  - memo / memoization / performance" >&2
            echo "" >&2
            echo "=== Vue Tier 1 (7 patterns) ===" >&2
            echo "  - vue component / sfc / vue" >&2
            echo "  - composable / composition / vue hook" >&2
            echo "  - pinia / pinia store / vue store" >&2
            echo "  - vue router / vue routes / router" >&2
            echo "  - directive / directives / vue directive" >&2
            echo "  - vue plugin / plugin / plugins" >&2
            echo "  - provide / inject / provide inject" >&2
            echo "" >&2
            echo "=== React Tier 2 (14 patterns) ===" >&2
            echo "  - nextjs middleware / middleware" >&2
            echo "  - nextjs loading / loading" >&2
            echo "  - nextjs error / error" >&2
            echo "  - background job / job / queue / worker" >&2
            echo "  - file upload / upload / file storage / storage" >&2
            echo "  - test / testing / mock / e2e / vitest / jest" >&2
            echo "  - theme / style / styling / design system / tailwind" >&2
            echo "  - server component / rsc / server" >&2
            echo "  - server action / action / actions" >&2
            echo "  - context / context provider / provider" >&2
            echo "  - types / type / interface / interfaces / typescript" >&2
            echo "  - config / configuration / environment / env" >&2
            echo "  - animation / motion / framer / spring" >&2
            echo "  - i18n / internationalization / localization / locale" >&2
            echo "" >&2
            echo "=== Vue Tier 2 (11 patterns) ===" >&2
            echo "  - nuxt page / nuxt" >&2
            echo "  - nuxt layout / nuxt layouts" >&2
            echo "  - nuxt middleware / nuxt route middleware" >&2
            echo "  - nuxt plugin / nuxt plugins" >&2
            echo "  - nuxt composable / nuxt composables" >&2
            echo "  - vue transition / transition / transitions" >&2
            echo "  - vue mixin / mixin / mixins" >&2
            echo "  - vue filter / filter / filters" >&2
            echo "  - vue test / vue testing / vue unit test" >&2
            echo "  - vue i18n / vue-i18n" >&2
            echo "  - vue router / router guard / navigation guard" >&2
        elif [ "$PROJECT_TYPE" = "python" ]; then
            echo "Supported patterns (Python/Django/FastAPI/Flask):" >&2
            echo "" >&2
            echo "Tier 1 - Core patterns (12):" >&2
            echo "  - model / models / orm / django model" >&2
            echo "  - view / views / django view / endpoint" >&2
            echo "  - serializer / schema / pydantic / marshmallow" >&2
            echo "  - service / services / business logic" >&2
            echo "  - repository / repo / data access" >&2
            echo "  - api / router / routing / fastapi / flask / routes / urls" >&2
            echo "  - form / forms / django form" >&2
            echo "  - task / celery / background job / worker" >&2
            echo "  - test / tests / pytest / unittest" >&2
            echo "  - admin / django admin" >&2
            echo "  - middleware / middlewares" >&2
            echo "  - config / settings / configuration" >&2
            echo "" >&2
            echo "Tier 2 - Supplementary patterns (14):" >&2
            echo "  - migration / migrations / alembic" >&2
            echo "  - command / management command / cli" >&2
            echo "  - util / utils / helpers" >&2
            echo "  - exception / exceptions / errors" >&2
            echo "  - validator / validators / validation" >&2
            echo "  - factory / factories / factory boy" >&2
            echo "  - fixture / fixtures / test data" >&2
            echo "  - signal / signals / django signal" >&2
            echo "  - manager / managers / django manager" >&2
            echo "  - mixin / mixins" >&2
            echo "  - decorator / decorators" >&2
            echo "  - client / http client / api client" >&2
            echo "  - pipeline / pipelines / scrapy pipeline" >&2
            echo "  - spider / spiders / scrapy / crawler" >&2
        else
            echo "Supported patterns (Swift/iOS):" >&2
            echo "" >&2
            echo "Tier 1 - Core patterns (14):" >&2
            echo "  - protocol / delegate / protocol delegate" >&2
            echo "  - combine / publisher / combine publisher (⚠️ needs content analysis)" >&2
            echo "  - async / await / async await / concurrency (⚠️ needs content analysis)" >&2
            echo "  - repository / repo / database / query" >&2
            echo "  - service / service layer / manager / networking / network" >&2
            echo "  - usecase / use case / interactor" >&2
            echo "  - router / route / routing / api endpoint / api" >&2
            echo "  - factory / builder / dependency injection / di" >&2
            echo "  - viewmodel / view model / mvvm / observable" >&2
            echo "  - view controller / viewcontroller" >&2
            echo "  - swiftui view / view" >&2
            echo "  - coordinator / navigation coordinator" >&2
            echo "  - core data / coredata / persistence" >&2
            echo "  - layout / collection view layout / uicollectionviewlayout" >&2
            echo "" >&2
            echo "Tier 2 - Supplementary patterns (15):" >&2
            echo "  - reducer / tca reducer / state reducer" >&2
            echo "  - environment / configuration / config" >&2
            echo "  - cache / caching" >&2
            echo "  - theme / style / appearance" >&2
            echo "  - mock / stub / fake / test double" >&2
            echo "  - middleware / interceptor" >&2
            echo "  - localization / i18n / l10n" >&2
            echo "  - animation / animator / transition" >&2
            echo "  - authentication / auth / login" >&2
            echo "  - background job / job / queue" >&2
            echo "  - file upload / upload / file storage" >&2
            echo "  - table view cell / collection view cell / cell" >&2
            echo "  - extension / extensions" >&2
            echo "  - view modifier / viewmodifier / swiftui modifier" >&2
            echo "  - error handling / error / errors" >&2
        fi
        exit 1
    fi

    # Normalize and get pattern components
    local normalized=$(normalize_pattern "$PATTERN")
    local file_patterns=$(get_file_patterns "$normalized" "$PROJECT_TYPE")
    local dir_patterns=$(get_dir_patterns "$normalized" "$PROJECT_TYPE")

    if [ -z "$file_patterns" ]; then
        echo "Error: Unknown pattern '$PATTERN'" >&2
        echo "Run with no arguments to see supported patterns." >&2
        exit 1
    fi

    # Use find with -name patterns (very fast)
    # Build find command with all file patterns
    local find_args=()
    local first=true
    for pattern in $file_patterns; do
        if [ "$first" = true ]; then
            find_args+=( "-name" "$pattern" )
            first=false
        else
            find_args+=( "-o" "-name" "$pattern" )
        fi
    done

    # Find all matching files and score them
    local temp_file=$(mktemp)
    trap "rm -f $temp_file" EXIT

    # Strategy 1: Find files matching file name patterns (score: 10 base + 8 if in relevant dir)
    find "$PROJECT_PATH" \( -type f -o -type d \) \( "${find_args[@]}" \) \
        ! -path "*/node_modules/*" \
        ! -path "*/.venv/*" \
        ! -path "*/venv/*" \
        ! -path "*/vendor/*" \
        ! -path "*/Pods/*" \
        ! -path "*/__pycache__/*" \
        ! -path "*/.git/*" \
        ! -path "*/DerivedData/*" \
        ! -path "*/build/*" \
        ! -path "*/.build/*" \
        ! -path "*/Carthage/*" \
        2>/dev/null | while IFS= read -r file; do
            # Skip directories unless they match .xcdatamodeld pattern
            if [ -d "$file" ] && [[ ! "$file" =~ \.xcdatamodeld$ ]]; then
                continue
            fi

        local score=10  # Base score for file name match

        # Check if in a relevant directory (+8 points)
        local dirname=$(dirname "$file")
        for dir_pattern in $dir_patterns; do
            if echo "$dirname" | tr '[:upper:]' '[:lower:]' | grep -qi "$dir_pattern"; then
                score=$((score + 8))
                break
            fi
        done

        echo "$score|$file"
    done > "$temp_file"

    # Strategy 2: Find all files in relevant directories (score: 8, lower than file name match)
    # This catches files like middleware/cors.py that don't match *middleware.py
    if [ -n "$dir_patterns" ] && [ "$PROJECT_TYPE" = "python" ]; then
        for dir_pattern in $dir_patterns; do
            # Find directories matching the pattern
            find "$PROJECT_PATH" -type d -iname "$dir_pattern" \
                ! -path "*/node_modules/*" \
                ! -path "*/.venv/*" \
                ! -path "*/venv/*" \
                ! -path "*/__pycache__/*" \
                ! -path "*/.git/*" \
                2>/dev/null | while IFS= read -r dir; do
                    # Find Python files in that directory
                    find "$dir" -maxdepth 1 -type f -name "*.py" 2>/dev/null | while IFS= read -r file; do
                        # Check if already in temp_file to avoid duplicates
                        if ! grep -qF "$file" "$temp_file" 2>/dev/null; then
                            echo "8|$file"
                        fi
                    done
            done
        done >> "$temp_file"
    fi

    # Sort by score (descending) and output top 10 files
    sort -t'|' -k1 -nr "$temp_file" | head -10 | cut -d'|' -f2
}

# Run main
main

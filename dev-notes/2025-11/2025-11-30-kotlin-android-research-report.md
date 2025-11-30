# Kotlin/Android Patterns Research Report

**Phase 1 Research - SourceAtlas Language Support Expansion**
**Date**: 2025-11-30
**Status**: Research Complete

---

## Executive Summary

This document presents the research findings for adding Kotlin/Android pattern support to SourceAtlas, following the [new-language-support-methodology.md](../archives/lessons/new-language-support-methodology.md) framework established from iOS expansion.

**Key Findings**:
- Kotlin/Android ecosystem is mature with well-defined architecture patterns
- MVVM is the dominant pattern (73%+ adoption), with MVI gaining ground
- Google's official guidance provides clear naming conventions
- Jetpack Compose is now mainstream (2023+), replacing XML layouts
- Hilt is the standard DI solution (replacing Dagger)

**Recommendation**: Proceed with Kotlin pattern implementation following the 6-phase methodology.

---

## 1. Language Ecosystem Analysis

### 1.1 Language Characteristics

```yaml
language: Kotlin
paradigm: OOP + FP (Multi-paradigm)
type_system: Static, Strong, Null-safe
memory: GC (JVM-based)
concurrency: Coroutines, Flow, StateFlow, SharedFlow

platform_targets:
  - Android (primary)
  - JVM (backend)
  - Multiplatform (KMP)
  - Native (via Kotlin/Native)

kotlin_version_evolution:
  - 1.3 (2018): Coroutines stable
  - 1.4 (2020): Improved Flow
  - 1.5 (2021): StateFlow, SharedFlow improvements
  - 1.9+ (2023+): K2 compiler, modern features
```

### 1.2 Ecosystem Maturity

| Aspect | Rating | Notes |
|--------|--------|-------|
| Community | ⭐⭐⭐⭐⭐ | Massive (Android is #1 mobile platform) |
| Official Docs | ⭐⭐⭐⭐⭐ | Google's Android Developer documentation is excellent |
| Frameworks | ⭐⭐⭐⭐⭐ | Jetpack, Compose, Hilt, Room, Retrofit |
| Stability | ⭐⭐⭐⭐⭐ | Very stable, Google-backed |
| Tooling | ⭐⭐⭐⭐⭐ | Android Studio, Gradle, Kotlin DSL |

### 1.3 Naming Conventions

**File Naming**:
- PascalCase for class files: `UserViewModel.kt`, `LoginRepository.kt`
- Single class per file (typically)
- Suffix indicates purpose: `*ViewModel`, `*Repository`, `*UseCase`

**Standard Suffixes**:

| Component | Suffix Pattern | Example |
|-----------|----------------|---------|
| ViewModel | `*ViewModel` | `UserViewModel.kt` |
| Repository | `*Repository` | `UserRepository.kt` |
| UseCase | `*UseCase` | `GetUserUseCase.kt` |
| Activity | `*Activity` | `MainActivity.kt` |
| Fragment | `*Fragment` | `HomeFragment.kt` |
| Adapter | `*Adapter` | `UserListAdapter.kt` |
| Service | `*Service` | `ApiService.kt` |
| DAO | `*Dao` | `UserDao.kt` |
| Entity | `*Entity` | `UserEntity.kt` |
| Module (DI) | `*Module` | `NetworkModule.kt` |

**Directory Structure Patterns**:

```
app/src/main/java/com/example/app/
├── data/
│   ├── local/          # Room database
│   │   ├── dao/
│   │   └── entity/
│   ├── remote/         # Network/API
│   │   └── api/
│   └── repository/
├── domain/
│   ├── model/
│   ├── repository/     # Interfaces
│   └── usecase/
├── presentation/       # or ui/
│   ├── home/
│   │   ├── HomeViewModel.kt
│   │   └── HomeScreen.kt
│   └── detail/
├── di/                 # Dependency Injection
└── util/               # or common/
```

---

## 2. Architecture Patterns Analysis

### 2.1 Architecture Evolution Timeline

```
2014-2017: Clean Architecture arrives
├── Layers: Presentation, Domain, Data
├── DI with Dagger takes off
└── MVP was common

2017-2020: RxJava era
├── Reactive programming mainstream
├── Early MVI/UDF ideas
└── MVVM gains popularity

2019-2022: Coroutines + Flow
├── Kotlin Coroutines replace RxJava
├── MVVM becomes default
├── Jetpack Compose introduced (2021)
└── Hilt replaces Dagger complexity

2023-2025: Modern Era ⭐
├── Jetpack Compose is mainstream
├── MVI with State Machine for complex apps
├── StateFlow/SharedFlow standard
├── Hilt is the standard DI
└── @Observable patterns emerging
```

### 2.2 Architecture Comparison

| Architecture | Popularity | Best For | Key Patterns |
|-------------|------------|----------|--------------|
| **MVVM** | ⭐⭐⭐⭐⭐ (73%+) | Most apps | ViewModel, LiveData/StateFlow, Repository |
| **Clean Architecture** | ⭐⭐⭐⭐ | Large/Enterprise | UseCase, Entity, Repository interfaces |
| **MVI** | ⭐⭐⭐⭐ (growing) | Complex state | Reducer, Intent, State, Side Effects |
| **MVP** | ⭐⭐ (legacy) | Old projects | Presenter, View interface |

### 2.3 Key Insights from Research

1. **MVVM is dominant** - 73%+ of Android apps use MVVM
2. **MVI is rising** - For complex state management (chat, real-time)
3. **Clean Architecture + MVVM** - Most enterprise apps combine both
4. **Compose changes patterns** - Different from XML-based architecture
5. **Hilt is standard** - Dagger complexity abstracted away

---

## 3. Framework-Specific Patterns

### 3.1 Jetpack Components

| Component | Purpose | Pattern Files |
|-----------|---------|---------------|
| **ViewModel** | UI state holder | `*ViewModel.kt` |
| **Room** | Local database | `*Dao.kt`, `*Entity.kt`, `*Database.kt` |
| **Hilt** | DI | `*Module.kt`, `@HiltViewModel` |
| **Navigation** | App navigation | `NavGraph.kt`, `*Screen.kt` |
| **Compose** | Declarative UI | `*Screen.kt`, `*Composable.kt` |
| **DataStore** | Preferences | `*DataStore.kt`, `*Preferences.kt` |

### 3.2 Networking Stack

| Library | Purpose | Pattern Files |
|---------|---------|---------------|
| **Retrofit** | REST API client | `*Api.kt`, `*ApiService.kt` |
| **OkHttp** | HTTP client | `*Interceptor.kt` |
| **Ktor** | Modern HTTP (KMP) | `*Client.kt` |

### 3.3 State Management

| Pattern | Type | Files |
|---------|------|-------|
| **StateFlow** | Hot stream | Used in ViewModels |
| **SharedFlow** | Event stream | Used for one-time events |
| **LiveData** | Lifecycle-aware (older) | Legacy projects |
| **MVI State** | Immutable state | `*State.kt`, `*Intent.kt` |

---

## 4. Modernization Indicators

### 4.1 Modern Code (2023+) ✅

- Jetpack Compose for UI
- Kotlin Coroutines + Flow
- Hilt for DI
- StateFlow/SharedFlow
- Material 3 Design
- Gradle Kotlin DSL (`build.gradle.kts`)
- Version Catalog (`libs.versions.toml`)

### 4.2 Transitional Code (2020-2022) 🟡

- Mix of XML + Compose
- LiveData + Coroutines
- Dagger 2 or early Hilt
- RxJava in some parts
- Groovy Gradle files

### 4.3 Legacy Code (pre-2020) 🔴

- XML layouts only
- Java mixed with Kotlin
- RxJava dominant
- Dagger 2 (complex setup)
- MVP architecture
- AsyncTask (deprecated)

---

## 5. Test Projects Candidates

### 5.1 Selection Criteria

Based on methodology, need 6+ projects covering:
- Scale: TINY → LARGE
- Architecture: MVVM, MVI, Clean Architecture
- UI: XML vs Compose
- High stars (>1000)

### 5.2 Recommended Test Projects

| Project | Stars | LOC Est. | Architecture | UI | Notes |
|---------|-------|----------|--------------|-----|-------|
| **[nowinandroid](https://github.com/android/nowinandroid)** | 18k+ | LARGE | Clean + MVVM | Compose | Google's official reference |
| **[Jepack-Compose-Samples](https://github.com/android/compose-samples)** | 20k+ | MEDIUM | Various | Compose | Official Compose examples |
| **[Pokedex](https://github.com/skydoves/Pokedex)** | 7k+ | MEDIUM | MVVM | XML | Popular, modern MVVM |
| **[Foodium](https://github.com/patilshreyas/Foodium)** | 2k+ | SMALL | MVVM | XML | Clean example |
| **[MVI-Coroutines-Flow](https://github.com/Suspended/MVI-Coroutines-Flow)** | 1k+ | SMALL | MVI | Mix | MVI reference |
| **[Jepack-Compose-MVI](https://github.com/AhmedVargos/Suspended)** | 500+ | SMALL | MVI + Compose | Compose | Modern MVI |
| **[tivi](https://github.com/chrisbanes/tivi)** | 6k+ | LARGE | Clean + MVVM | Compose | Production quality |

### 5.3 Coverage Matrix

| Dimension | Coverage |
|-----------|----------|
| SMALL (1-5K) | Foodium, MVI-Flow |
| MEDIUM (5-50K) | Pokedex, Compose-Samples |
| LARGE (50K+) | nowinandroid, tivi |
| MVVM | Pokedex, Foodium, nowinandroid |
| MVI | MVI-Flow, tivi |
| Clean Architecture | nowinandroid, tivi |
| Compose | nowinandroid, Compose-Samples, tivi |
| XML | Pokedex, Foodium |

---

## 6. Pattern Candidates (Initial List)

### 6.1 Tier 1 - Core Patterns (10-12)

| # | Pattern | Importance | File Patterns | Directory Patterns |
|---|---------|------------|---------------|-------------------|
| 1 | **ViewModel** | ⭐⭐⭐⭐⭐ | `*ViewModel.kt` | `viewmodel/`, `presentation/` |
| 2 | **Repository** | ⭐⭐⭐⭐⭐ | `*Repository.kt`, `*RepositoryImpl.kt` | `repository/`, `data/` |
| 3 | **UseCase/Interactor** | ⭐⭐⭐⭐⭐ | `*UseCase.kt`, `*Interactor.kt` | `usecase/`, `domain/` |
| 4 | **Entity/Model** | ⭐⭐⭐⭐⭐ | `*Entity.kt`, `*Model.kt` | `entity/`, `model/` |
| 5 | **DAO** | ⭐⭐⭐⭐⭐ | `*Dao.kt` | `dao/`, `local/` |
| 6 | **ApiService** | ⭐⭐⭐⭐⭐ | `*Api.kt`, `*ApiService.kt` | `api/`, `remote/` |
| 7 | **DI Module** | ⭐⭐⭐⭐⭐ | `*Module.kt` | `di/`, `injection/` |
| 8 | **Adapter** | ⭐⭐⭐⭐ | `*Adapter.kt` | `adapter/` |
| 9 | **Fragment** | ⭐⭐⭐⭐ | `*Fragment.kt` | `fragment/`, `ui/` |
| 10 | **Activity** | ⭐⭐⭐⭐ | `*Activity.kt` | `activity/` |

### 6.2 Tier 2 - Supplementary Patterns (8-10)

| # | Pattern | Importance | File Patterns | Notes |
|---|---------|------------|---------------|-------|
| 11 | **Screen (Compose)** | ⭐⭐⭐⭐ | `*Screen.kt` | Compose UI |
| 12 | **State (MVI)** | ⭐⭐⭐ | `*State.kt`, `*UiState.kt` | MVI/UDF |
| 13 | **Intent/Event** | ⭐⭐⭐ | `*Intent.kt`, `*Event.kt` | MVI |
| 14 | **Mapper** | ⭐⭐⭐ | `*Mapper.kt` | Data transformation |
| 15 | **DataSource** | ⭐⭐⭐ | `*DataSource.kt` | Clean Architecture |
| 16 | **Interceptor** | ⭐⭐⭐ | `*Interceptor.kt` | OkHttp |
| 17 | **Worker** | ⭐⭐⭐ | `*Worker.kt` | WorkManager |
| 18 | **Database** | ⭐⭐⭐ | `*Database.kt` | Room |
| 19 | **Composable** | ⭐⭐⭐ | `*Composable.kt` | UI components |
| 20 | **Test/Mock** | ⭐⭐⭐ | `*Test.kt`, `Fake*.kt`, `Mock*.kt` | Testing |

### 6.3 Tier 3 - Advanced (Optional)

| Pattern | Notes |
|---------|-------|
| Reducer | MVI-specific |
| Middleware | Redux-like |
| Navigator | Custom navigation |
| Preferences/DataStore | Local storage |
| Broadcast Receiver | Android component |
| Service (Android) | Background service |

---

## 7. Implementation Roadmap

### Phase 1: Tier 1 Implementation (2 weeks)

**Week 1** (5 patterns - highest priority):
1. ViewModel
2. Repository
3. UseCase
4. DAO
5. ApiService

**Week 2** (5 patterns):
6. DI Module
7. Entity/Model
8. Adapter
9. Fragment
10. Activity

### Phase 2: Tier 2 Implementation (1 week)

11-20: Compose Screen, State, Mapper, DataSource, etc.

### Phase 3: Testing & Documentation

- Cross-project validation
- Documentation
- Update CLAUDE.md and PROMPTS.md

---

## 8. Key Differences from iOS

| Aspect | iOS (Swift) | Android (Kotlin) |
|--------|-------------|------------------|
| UI Framework | SwiftUI / UIKit | Compose / XML Views |
| DI | No standard (DIContainer) | Hilt (standard) |
| Reactive | Combine / async-await | Flow / Coroutines |
| Architecture | MVVM, TCA, Clean | MVVM, MVI, Clean |
| State | @Observable | StateFlow |
| Navigation | NavigationStack | Navigation Component |
| Database | CoreData / SwiftData | Room |
| Networking | URLSession | Retrofit/Ktor |

**Key Insight**: Kotlin/Android has more standardized patterns due to Google's official guidance (Jetpack). iOS has more fragmentation.

---

## 9. Next Steps

1. **Clone test projects** (6-7 projects)
2. **Create project profiles** for each
3. **Begin Tier 1 Week 1 implementation**
4. **Test each pattern on 2+ projects**
5. **Document findings and adjustments**

---

## Sources

### Architecture & Patterns
- [Modern Android App Architecture in 2025](https://medium.com/@androidlab/modern-android-app-architecture-in-2025-mvvm-mvi-and-clean-architecture-with-jetpack-compose-c0df3c727334)
- [MVVM vs MVI vs Clean Architecture Guide 2025](https://medium.com/@hiren6997/the-architecture-war-why-73-of-android-apps-choose-wrong-and-how-to-pick-the-right-one-76008986a2ab)
- [Ultimate Guide to Modern Android Architecture 2025](https://medium.com/@hiren6997/the-ultimate-guide-to-modern-android-app-architecture-2025-edition-963ce4bc8bfc)
- [Android Architecture Patterns Overview](https://medium.com/droidblogs/android-architecture-patterns-mvc-mvp-mvvm-mvi-clean-architecture-cde8029b8f37)
- [15 Years of Android App Architectures - droidcon](https://www.droidcon.com/2025/10/20/15-years-of-android-app-architectures/)

### Jetpack Compose & ViewModel
- [Repository Pattern with Jetpack Compose - Kodeco](https://www.kodeco.com/24509368-repository-pattern-with-jetpack-compose)
- [Crafting Scalable Android Architecture with MVVM, Compose, Hilt](https://medium.com/@rushabhprajapati20/crafting-a-scalable-android-architecture-with-mvvm-jetpack-compose-hilt-and-usecase-0a0ba32ca438)
- [Thinking in Compose - Android Developers](https://developer.android.com/develop/ui/compose/mental-model)
- [How to Use ViewModel with Jetpack Compose](https://medium.com/appcent/how-to-use-viewmodel-with-jetpack-compose-dc543f10bf6f)

### Naming Conventions
- [Kotlin Coding Conventions](https://kotlinlang.org/docs/coding-conventions.html)
- [Kotlin Style Guide - Android Developers](https://developer.android.com/kotlin/style-guide)
- [Android Handbook - Naming](https://infinum.com/handbook/android/building-quality-apps/naming)
- [Organizing Source Files - CodePath](https://guides.codepath.com/android/Organizing-your-Source-Files)

### Dependency Injection
- [Hilt Official Documentation](https://dagger.dev/hilt/)
- [Dependency Injection with Hilt - Android Developers](https://developer.android.com/training/dependency-injection/hilt-android)
- [Mastering DI with Dagger Hilt](https://medium.com/@nirav.tukadiya/mastering-dependency-injection-in-android-using-dagger-hilt-a-complete-tutorial-with-kotlin-6f4d9087ae85)

### Room Database
- [Save data using Room - Android Developers](https://developer.android.com/training/data-storage/room)
- [Define data using Room entities](https://developer.android.com/training/data-storage/room/defining-data)
- [Accessing data using Room DAOs](https://developer.android.com/training/data-storage/room/accessing-data)

### Coroutines & Flow
- [Ultimate Guide to Kotlin Coroutines: Flow, StateFlow, SharedFlow](https://medium.com/@alamiin345/ultimate-guide-to-kotlin-coroutines-in-android-flow-stateflow-and-sharedflow-explained-e1ff473574ec)
- [StateFlow and SharedFlow - Android Developers](https://developer.android.com/kotlin/flow/stateflow-and-sharedflow)
- [Kotlin Flows on Android](https://developer.android.com/kotlin/flow)

### Sample Projects
- [Now in Android - GitHub](https://github.com/android/nowinandroid)
- [Awesome Android Kotlin Apps](https://github.com/androiddevnotes/awesome-android-kotlin-apps)
- [Awesome Android Open Source Projects](https://github.com/binaryshrey/Awesome-Android-Open-Source-Projects)

### Networking
- [Consuming APIs with Retrofit - CodePath](https://guides.codepath.com/android/consuming-apis-with-retrofit)
- [Implementation of Hilt in Retrofit](https://dev.to/krisrajkumar/implementation-of-hilt-in-retrofit-154f)

---

**Report Version**: v1.0
**Author**: SourceAtlas Research
**Next Phase**: Test Project Setup & Pattern Tiering

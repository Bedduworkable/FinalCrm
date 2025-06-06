# igplrealestatecrm

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Firestore optimization

This project includes optional utilities in `lib/firestore_optimization.dart`
to reduce Firestore reads and writes. To enable offline caching at startup,
add the following call after Firebase initialization:

```dart
await FirestoreOptimization.enableOfflinePersistence();
```

Other helpers in the file provide paginated lead fetching and denormalized
write operations. The app now uses these helpers through `DatabaseService`
methods like `createLeadWithSummary`, `createFollowUpWithSummary`, and
`fetchLeadsPage` to reduce the number of Firestore reads and writes.

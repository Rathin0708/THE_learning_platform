/// Infrastructure layer for `home`. Nothing platform-specific is needed by
/// the home screen in the MVP build (no notifications/widgets yet) — this
/// file exists to keep the layer boundary explicit so platform code (e.g. a
/// future home-screen widget or daily-reminder notification) has an obvious,
/// pre-agreed place to live rather than leaking into `presentation/`.
library home_infrastructure;

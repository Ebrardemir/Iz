// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppL10nEn extends AppL10n {
  AppL10nEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'İZ';

  @override
  String get appTagline => 'Choose, collect and keep alive what leaves a trace';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonSave => 'Save';

  @override
  String get commonDelete => 'Delete';

  @override
  String get commonEdit => 'Edit';

  @override
  String get commonRetry => 'Try again';

  @override
  String get commonClose => 'Close';

  @override
  String get commonDone => 'Done';

  @override
  String get commonShare => 'Share';

  @override
  String get commonSearch => 'Search';

  @override
  String get commonSeeAll => 'See All';

  @override
  String get commonAdd => 'Add';

  @override
  String get commonNext => 'Next';

  @override
  String get commonSkip => 'Skip';

  @override
  String get commonLoading => 'Loading';

  @override
  String get authWelcomeBack => 'Welcome back';

  @override
  String get authWelcomeSubtitle => 'Pick up your memories where you left off.';

  @override
  String get authEmail => 'Email';

  @override
  String get authPassword => 'Password';

  @override
  String get authForgotPassword => 'Forgot my password';

  @override
  String get authSignIn => 'Sign In';

  @override
  String get authCreateAccount => 'Create Account';

  @override
  String get authOr => 'or';

  @override
  String get authSignInWithApple => 'Sign in with Apple';

  @override
  String get authSignInWithGoogle => 'Sign in with Google';

  @override
  String get authPrivacyNote => 'Your data is safe. We respect your privacy.';

  @override
  String get authShowPassword => 'Show password';

  @override
  String get authHidePassword => 'Hide password';

  @override
  String get authHeroSemantics => 'A collage of memory photographs';

  @override
  String get authResetLinkSent => 'Password reset link sent.';

  @override
  String get authResetNeedsEmail => 'Enter your email address first.';

  @override
  String get authFullName => 'Full Name';

  @override
  String get authPasswordAgain => 'Repeat password';

  @override
  String get authSignUp => 'Sign Up';

  @override
  String get authContinueWithApple => 'Continue with Apple';

  @override
  String get authContinueWithGoogle => 'Continue with Google';

  @override
  String get authAlreadyHaveAccount => 'Already have an account?';

  @override
  String get navHome => 'Home';

  @override
  String get navMyLife => 'My Life';

  @override
  String get navAdd => 'Add';

  @override
  String get navStore => 'Store';

  @override
  String get navProfile => 'Profile';

  @override
  String get myLifePreviousMonth => 'Previous month';

  @override
  String get myLifeNextMonth => 'Next month';

  @override
  String get myLifeTabCalendar => 'CALENDAR';

  @override
  String get myLifeTabCollections => 'COLLECTIONS';

  @override
  String get myLifeTabSeries => 'MY SERIES';

  @override
  String get myLifeTitle => 'MY LIFE';

  @override
  String get myLifeDayEmptyTitle => 'No trace left on this day yet';

  @override
  String get myLifeDayEmptyAction => 'Leave a trace on this day';

  @override
  String get collectionsEmptyTitle => 'No collections yet';

  @override
  String get collectionsEmptyMessage =>
      'Gather the memories of a trip, a season or a person into a single collection.';

  @override
  String get collectionExpand => 'Expand collection';

  @override
  String get collectionNewTitle => 'New Collection';

  @override
  String get collectionFieldName => 'Collection Name';

  @override
  String get collectionFieldNameHint => 'Enter a collection name';

  @override
  String get collectionFieldDescription => 'Description';

  @override
  String get collectionFieldDescriptionHint =>
      'Describe your collection briefly';

  @override
  String get collectionFieldDateRange => 'Date Range';

  @override
  String get collectionFieldDateRangeHint => 'Start – End';

  @override
  String get collectionFieldPeople => 'Related People';

  @override
  String get collectionFieldPeopleHint => 'Add people';

  @override
  String get collectionFieldCategory => 'Category';

  @override
  String get collectionFieldCategoryHint => 'Pick a category';

  @override
  String get collectionFieldMemories => 'Add First Memories';

  @override
  String get collectionFieldMemoriesHint => 'Start by picking memories';

  @override
  String collectionSelectedMemories(int count) {
    return '$count memories selected';
  }

  @override
  String get collectionCreateAction => 'Create Collection';

  @override
  String get collectionNameRequired =>
      'We need a name before we can create it.';

  @override
  String get collectionCreated =>
      'Your collection is ready, waiting in My Life.';

  @override
  String get collectionCollapse => 'Collapse collection';

  @override
  String collectionMemoryCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count memories',
      one: '1 memory',
      zero: 'No memories',
    );
    return '$_temp0';
  }

  @override
  String get addMenuTitle => 'What would you like to add?';

  @override
  String get addMenuMemory => 'Memory';

  @override
  String get addMenuSeries => 'Series';

  @override
  String get addMenuJournal => 'Journal entry';

  @override
  String get addMenuCollection => 'Collection';

  @override
  String get addMenuPerson => 'Person';

  @override
  String get seriesEmptyTitle => 'No series yet';

  @override
  String get seriesEmptyMessage =>
      'Tie the things that repeat every year into a series, and see the years side by side.';

  @override
  String ritualEveryYearOn(String month, int day) {
    String _temp0 = intl.Intl.selectLogic(month, {
      '1': 'Every year on January $day',
      '2': 'Every year on February $day',
      '3': 'Every year on March $day',
      '4': 'Every year on April $day',
      '5': 'Every year on May $day',
      '6': 'Every year on June $day',
      '7': 'Every year on July $day',
      '8': 'Every year on August $day',
      '9': 'Every year on September $day',
      '10': 'Every year on October $day',
      '11': 'Every year on November $day',
      '12': 'Every year on December $day',
      'other': 'Every year',
    });
    return '$_temp0';
  }

  @override
  String ritualEveryYearInSeason(String season) {
    String _temp0 = intl.Intl.selectLogic(season, {
      'spring': 'Every spring',
      'summer': 'Every summer',
      'autumn': 'Every autumn',
      'winter': 'Every winter',
      'other': 'Every year',
    });
    return '$_temp0';
  }

  @override
  String get ritualCustomSchedule => 'No fixed date';

  @override
  String get ritualEveryMonth => 'Every month';

  @override
  String get ritualEveryWeek => 'Every week';

  @override
  String get ritualNewTitle => 'New Series';

  @override
  String get coverAdd => 'Add Cover Image';

  @override
  String get coverChange => 'Change Cover Image';

  @override
  String get coverIllustrationSemantics =>
      'Drawing of mountains, a sun and an olive branch';

  @override
  String get ritualFieldName => 'Series Name';

  @override
  String get ritualFieldNameHint => 'Give your series a name';

  @override
  String get ritualFieldDescription => 'Description';

  @override
  String get ritualFieldDescriptionHint =>
      'Write a short note about this series';

  @override
  String get ritualFieldRecurrence => 'Repeats';

  @override
  String get ritualFieldPeople => 'Related People';

  @override
  String get ritualFieldPeopleHint => 'Add people';

  @override
  String get ritualFieldCategory => 'Category';

  @override
  String get ritualFieldCategoryHint => 'Pick a category';

  @override
  String get ritualFieldMemories => 'Add This Year\'s Memory';

  @override
  String get ritualFieldMemoriesHint => 'Link memories to this series';

  @override
  String ritualSelectedMemories(int count) {
    return '$count memories selected';
  }

  @override
  String ritualDateRange(String range) {
    return 'Date range: $range';
  }

  @override
  String get ritualCreateAction => 'Create Series';

  @override
  String get ritualNameRequired => 'We need a name before we can create it.';

  @override
  String get ritualCreated => 'Your series is ready, waiting in My Series.';

  @override
  String get memoryPickerTitle => 'Pick Memories';

  @override
  String get memoryPickerEmpty =>
      'No memories left to link. A memory can belong to only one series.';

  @override
  String get memoryPickerDone => 'Done';

  @override
  String ritualStatYears(int count) {
    return '$count yr';
  }

  @override
  String get ritualStatYearsLabel => 'Together';

  @override
  String ritualStatMemories(int count) {
    return '$count memories';
  }

  @override
  String get ritualStatMemoriesLabel => 'In total';

  @override
  String ritualStatCities(int count) {
    return '$count cities';
  }

  @override
  String get ritualStatCitiesLabel => 'Explored';

  @override
  String get ritualDetailMemories => 'Memories in This Series';

  @override
  String get ritualDetailShowAll => 'See All';

  @override
  String get ritualDetailShowLess => 'Show Less';

  @override
  String get ritualDetailNoMemories =>
      'No memories linked to this series yet. Every one you link will gather here, year by year.';

  @override
  String get ritualDetailActions => 'Series actions';

  @override
  String get ritualEditAction => 'Edit Series';

  @override
  String get ritualDeleteAction => 'Delete Series';

  @override
  String get ritualDeleteTitle => 'Delete this series?';

  @override
  String get ritualDeleteMessage =>
      'This series will be removed. The memories stay — only their links to the series are broken.';

  @override
  String get ritualRecurrenceSectionSemantics => 'Recurrence options';

  @override
  String ritualYearCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count years',
      one: '1 year',
      zero: 'No years',
    );
    return '$_temp0';
  }

  @override
  String get memoryMoreActions => 'Memory actions';

  @override
  String get memoryOpenDetail => 'Open memory';

  @override
  String get commonFilter => 'Filter';

  @override
  String get homeHeroTodayEyebrow => 'TODAY\'S TRACE';

  @override
  String get homeHeroViewMemory => 'View Memory';

  @override
  String get homeHeroEmptyTitle => 'Leave Your First Trace';

  @override
  String get homeHeroEmptySubtitle =>
      'Choose a moment you\'ll want to remember, and keep it.';

  @override
  String get homeHeroAddMemory => 'Add Memory';

  @override
  String get homeRecentTitle => 'RECENT TRACES';

  @override
  String get homeRecentEmptyTitle => 'No traces here yet.';

  @override
  String get homeRecentEmptyMessage =>
      'Your first memory will show up here once you add it.';

  @override
  String get homeStatJournal => 'JOURNAL';

  @override
  String homeStatJournalUnit(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'records',
      one: 'record',
    );
    return '$_temp0';
  }

  @override
  String get homeStatPeople => 'PEOPLE';

  @override
  String homeStatPeopleUnit(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'people',
      one: 'person',
    );
    return '$_temp0';
  }

  @override
  String get homeStatSeries => 'SERIES';

  @override
  String homeStatSeriesUnit(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'series',
      one: 'series',
    );
    return '$_temp0';
  }

  @override
  String get homeStatCollections => 'COLLECTIONS';

  @override
  String homeStatCollectionsUnit(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'collections',
      one: 'collection',
    );
    return '$_temp0';
  }

  @override
  String get homeNotifications => 'Notifications';

  @override
  String get screenComingSoon => 'Coming soon';

  @override
  String get screenComingSoonMessage =>
      'We\'re designing this screen. It\'ll be here soon.';

  @override
  String get navJournal => 'Journal';

  @override
  String get navPeople => 'People';

  @override
  String get navSettings => 'Settings';

  @override
  String get memoriesTitle => 'My Memories';

  @override
  String get memoryNew => 'New Memory';

  @override
  String get memoryEdit => 'Edit Memory';

  @override
  String get memoryFavorite => 'Add to favorites';

  @override
  String get memoryUnfavorite => 'Remove from favorites';

  @override
  String get memoryFilterFavoritesOff => 'Show favorites only';

  @override
  String get memoryFilterFavoritesOn => 'Clear favorites filter';

  @override
  String get memoryEmptyTitle => 'No traces yet';

  @override
  String get memoryEmptyMessage =>
      'Don\'t copy your whole gallery — collect only the moments worth keeping. Start with your first trace.';

  @override
  String get memoryEmptyAction => 'Leave your first trace';

  @override
  String get memoryDeleteTitle => 'Delete this memory?';

  @override
  String get memoryDeleteMessage =>
      'It will be moved to trash. You can restore it within 30 days.';

  @override
  String get memoryDeleteConfirm => 'Delete';

  @override
  String get memoryDeleted => 'Memory moved to trash';

  @override
  String get memoryRestore => 'Undo';

  @override
  String memoryCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count memories',
      one: '1 memory',
      zero: 'No memories',
    );
    return '$_temp0';
  }

  @override
  String memoryYearsAgo(int years) {
    String _temp0 = intl.Intl.pluralLogic(
      years,
      locale: localeName,
      other: '$years years ago today',
      one: 'One year ago today',
      zero: 'Today',
    );
    return '$_temp0';
  }

  @override
  String get memoryFieldTitle => 'Title';

  @override
  String get memoryFieldTitleHint => 'What was this moment?';

  @override
  String get memoryFieldNote => 'Note';

  @override
  String get memoryFieldNoteHint => 'What do you want to remember?';

  @override
  String get memoryFieldDate => 'Date';

  @override
  String get memoryFieldCategory => 'Category';

  @override
  String get memoryFieldCollection => 'Collection';

  @override
  String get memoryFieldSeries => 'Series';

  @override
  String get memoryFieldLocationHint => 'Where was it?';

  @override
  String get memoryFieldEmpty => 'Choose';

  @override
  String get memoryDetailsTitle => 'Add Details';

  @override
  String memoryDateInvalid(String example) {
    return 'I couldn\'t read that date. Example: $example';
  }

  @override
  String get memoryDateFuture => 'You can\'t pick a future date.';

  @override
  String get pickerAddNew => 'Add new';

  @override
  String get pickerEmpty => 'Nothing here yet. You can add one below.';

  @override
  String get memoryPhotos => 'Photos';

  @override
  String get memoryNoPhotos => 'No photos added yet.';

  @override
  String get memoryDetailTitle => 'Memory Detail';

  @override
  String get memoryActionCollage => 'Create Collage';

  @override
  String get memoryNoteExpand => 'Show the full note';

  @override
  String get memoryNoteCollapse => 'Collapse the note';

  @override
  String get memoryPhotosPrompt => 'Which frames should remain of this memory?';

  @override
  String get memoryPickFromGallery => 'Choose from Gallery';

  @override
  String memoryPhotoLimitHint(int limit) {
    return 'You can choose up to $limit photos.';
  }

  @override
  String get memoryPhotosIllustrationSemantics =>
      'An illustration of photo frames and a sprig';

  @override
  String get commonSaveChanges => 'Save Changes';

  @override
  String get memoryPhotoRemove => 'Remove photo';

  @override
  String get memoryPhotoAdd => 'Add photo';

  @override
  String get relationPeople => 'People';

  @override
  String get relationCollections => 'Collections';

  @override
  String get relationRitual => 'Series';

  @override
  String get relationLocation => 'Location';

  @override
  String photoLimitReached(int limit) {
    return 'On the free plan you can add up to $limit photos to a memory.';
  }

  @override
  String get todaysTraceTitle => 'Today\'s Trace';

  @override
  String get todaysTraceSubtitle =>
      'Remind me what I lived on this day in past years';

  @override
  String get thenAndNowTitle => 'Then / Now';

  @override
  String get onboardingCurateTitle =>
      'Not your whole gallery —\njust what left a trace';

  @override
  String get onboardingCurateBody =>
      'İZ is not a backup app. It\'s a personal memory where you choose the moments that truly matter to you and give them meaning.';

  @override
  String get onboardingContextTitle => 'One memory,\nmany contexts';

  @override
  String get onboardingContextBody =>
      'Link the same memory to people, categories, collections and rituals. Find it in seconds years later, without getting lost in folders.';

  @override
  String get onboardingLocalTitle => 'Your data stays\non this device for now';

  @override
  String get onboardingLocalBody =>
      'Your memories are stored on your phone and shared with no one. But if you lose your phone, they go with it — so we\'ll remind you to export regularly.';

  @override
  String get onboardingStart => 'Leave your first trace';

  @override
  String get journalEmptyTitle => 'What would you like to note today?';

  @override
  String get journalEmptyMessage =>
      'A short note is enough. You can turn it into a lasting memory later.';

  @override
  String get journalNewTitle => 'New Journal';

  @override
  String get journalGreeting => 'Hello';

  @override
  String get journalPrompt1 =>
      'What tired you today, what made you smile? Leave a few lines; tomorrow you will be glad you did.';

  @override
  String get journalPrompt2 =>
      'Write it not to remember, but to find it when you want to.';

  @override
  String get journalPrompt3 =>
      'Small things count too: a coffee, a word, a glance. All of it is today\'s trace.';

  @override
  String get journalPrompt4 =>
      'Your words don\'t have to be polished. Telling it is enough.';

  @override
  String get journalPrompt5 =>
      'What would you like left from today? Write that, leave the rest to time.';

  @override
  String get journalMoodLow => 'A hard day';

  @override
  String get journalMoodHigh => 'A good day';

  @override
  String get journalIllustrationSemantics =>
      'Drawing of an open notebook and an olive branch';

  @override
  String get journalMoodQuestion => 'How are you feeling today?';

  @override
  String journalMoodSemantics(int value) {
    return 'Your mood today: $value';
  }

  @override
  String get journalFieldTitle => 'Title';

  @override
  String get journalFieldTitleHint => 'Give today a name';

  @override
  String get journalFieldNotes => 'My Notes';

  @override
  String get journalFieldNotesHint => 'Write whatever is on your mind…';

  @override
  String get journalPhotosLabel => 'A frame from today';

  @override
  String journalPhotosHint(int count) {
    return 'Add up to $count photos if you like.';
  }

  @override
  String get journalCreateAction => 'Create Entry';

  @override
  String get journalNotesRequired => 'We need a few words before we can save.';

  @override
  String get journalCreated => 'Today\'s trace is saved.';

  @override
  String get journalHeroGreeting => 'Welcome';

  @override
  String journalHeroGreetingNamed(String name) {
    return 'Welcome, $name';
  }

  @override
  String get journalHeroBody =>
      'Keep yourself company today, even with a few lines.';

  @override
  String get journalHeroAction => 'Start Writing';

  @override
  String get journalHeroSemantics =>
      'Drawing of an open notebook, a pen and a coffee on a desk';

  @override
  String get journalRecentTitle => 'My Recent Entries';

  @override
  String get journalRecentEmptyTitle => 'This is your quiet corner';

  @override
  String get journalRecentEmptyBody =>
      'Every line you write becomes a trace you will come back to find.';

  @override
  String get journalEmptyIllustrationSemantics =>
      'Drawing of a blank page, a pen and a sprig';

  @override
  String get journalAllTitle => 'All Entries';

  @override
  String get journalFilterAll => 'All';

  @override
  String get journalFilterThisWeek => 'This Week';

  @override
  String get journalFilterThisMonth => 'This Month';

  @override
  String get journalFilterFavorites => 'Starred';

  @override
  String get journalAllEmptyWeek =>
      'You haven\'t written this week yet. There is still time for a line.';

  @override
  String get journalAllEmptyMonth =>
      'Nothing written this month. Pick a day before it closes and write.';

  @override
  String get journalAllEmptyFavorites =>
      'You haven\'t starred anything yet. If there is a day you keep coming back to, mark it.';

  @override
  String get journalFavoriteAdd => 'Star';

  @override
  String get journalFavoriteRemove => 'Remove star';

  @override
  String get peopleEmptyTitle => 'This page will fill up with them.';

  @override
  String get peopleEmptyMessage =>
      'Your mother, your closest friend, maybe your cat… Add someone and everything you lived together starts gathering on a single thread.';

  @override
  String get peopleTitle => 'My People';

  @override
  String get peopleSubtitle =>
      'The people who left a trace in your life live here.';

  @override
  String get peopleEmptyAction => 'Add Your First Person';

  @override
  String get peopleIllustrationSemantics =>
      'Drawing of three people standing under a dome';

  @override
  String get relationTypeSelf => 'Myself';

  @override
  String get relationTypePartner => 'My partner';

  @override
  String get relationTypeParent => 'Parent';

  @override
  String get relationTypeChild => 'My child';

  @override
  String get relationTypeSibling => 'My sibling';

  @override
  String get relationTypeGrandparent => 'Grandparent';

  @override
  String get relationTypeGrandchild => 'My grandchild';

  @override
  String get relationTypeRelative => 'My relative';

  @override
  String get relationTypeFriend => 'My friend';

  @override
  String get relationTypeColleague => 'My colleague';

  @override
  String get relationTypePet => 'My companion';

  @override
  String get relationTypeOther => 'Close to me';

  @override
  String get peopleAddAction => 'Add Person';

  @override
  String get peopleSearchHint => 'Search people';

  @override
  String get peopleSearchClear => 'Clear search';

  @override
  String get personNewTitle => 'New Person';

  @override
  String get personPhotoAdd => 'Add Photo';

  @override
  String get personPhotoChange => 'Change photo';

  @override
  String get personPhotoRemove => 'Remove photo';

  @override
  String get personFieldName => 'Name';

  @override
  String get personFieldNameHint => 'e.g. Elif';

  @override
  String get personFieldRelation => 'Your relationship';

  @override
  String get personFieldRelationHint => 'e.g. My mother';

  @override
  String get personFieldBirthDate => 'Date of Birth';

  @override
  String get personFieldBirthDateHint => 'Pick a date';

  @override
  String get personFieldNote => 'Short Note';

  @override
  String get personFieldNoteHint => 'Add a note about this person…';

  @override
  String get personSaveAction => 'Save Person';

  @override
  String get personNameRequired => 'We can\'t save without a name.';

  @override
  String get personBirthDateFuture =>
      'A date of birth can\'t be in the future.';

  @override
  String get formOptional => '(Optional)';

  @override
  String get personDetailCollections => 'Our Collections';

  @override
  String get personDetailRituals => 'Our Series';

  @override
  String get personDetailNoCollections =>
      'No collection you share with them yet.';

  @override
  String get personDetailNoRituals => 'No series you repeat together yet.';

  @override
  String get personEditAction => 'Edit Person';

  @override
  String get personDeleteAction => 'Delete Person';

  @override
  String get personActions => 'Person actions';

  @override
  String get personDeleteTitle => 'Delete this person?';

  @override
  String get personDeleteMessage =>
      'This person will be removed. The memories you shared stay — only the link is broken.';

  @override
  String get personEditTitle => 'Edit Person';

  @override
  String ritualDurationYears(int count) {
    return '$count yr';
  }

  @override
  String myLifeFilteredByPerson(String name) {
    return 'with $name';
  }

  @override
  String get myLifeClearFilter => 'Clear filter';

  @override
  String get peopleSearchEmptyTitle => 'I couldn\'t find that person';

  @override
  String peopleSearchEmptyMessage(String query) {
    return 'No one matches \"$query\". Try another name or relationship.';
  }

  @override
  String peopleOpenDetail(String name) {
    return 'Open $name\'s page';
  }

  @override
  String get searchPromptTitle => 'Search your memories';

  @override
  String get searchPromptMessage =>
      'You can search titles and notes. Search works without an internet connection too.';

  @override
  String get searchNoResultsTitle => 'No results found';

  @override
  String get searchNoResultsMessage =>
      'Try a different word, or clear your filters.';

  @override
  String get backupLocalOnly => 'On this device only';

  @override
  String get backupLocalOnlyDetail =>
      'Your data lives only on this phone. If you lose it, your memories go with it.';

  @override
  String get backupExportNow => 'Export now';

  @override
  String backupLastExport(String date) {
    return 'Last export: $date';
  }

  @override
  String get backupNeverExported => 'You haven\'t exported yet';

  @override
  String get mediaMissingTitle => 'Original photo not found';

  @override
  String get mediaMissingMessage =>
      'This photo seems to have been deleted from your gallery. Showing the preview İZ kept.';

  @override
  String get paywallTitle => 'Unlock with İZ+';

  @override
  String paywallFeatureLocked(String plan) {
    return 'This feature is available on the $plan plan.';
  }

  @override
  String get errorGeneric => 'Something went wrong. Please try again.';

  @override
  String get errorDatabase => 'We can\'t reach your data right now.';

  @override
  String get errorNotFound => 'We couldn\'t find that record.';

  @override
  String get errorPermission => 'Permission is required to continue.';

  @override
  String get errorPermissionSettings => 'You can grant it in Settings.';

  @override
  String get errorNetwork => 'Couldn\'t connect.';

  @override
  String get errorOffline => 'You appear to be offline.';

  @override
  String get errorValidationEmptyMemory =>
      'A memory needs at least a note or one photo.';

  @override
  String get errorValidationFutureDate =>
      'A memory can\'t be dated in the future.';

  @override
  String get errorValidationEmailRequired => 'Enter your email address.';

  @override
  String get errorValidationEmailInvalid => 'Enter a valid email address.';

  @override
  String get errorValidationPasswordRequired => 'Enter your password.';

  @override
  String errorValidationPasswordTooShort(int min) {
    return 'Password must be at least $min characters.';
  }

  @override
  String get errorSignInFailed => 'Email or password is incorrect.';

  @override
  String get errorValidationNameRequired => 'Enter your full name.';

  @override
  String get errorValidationPasswordsDoNotMatch => 'Passwords don\'t match.';

  @override
  String get routeNotFound => 'Page not found';

  @override
  String get routeNotImplemented => 'This screen isn\'t ready yet.';

  @override
  String get routeGoHome => 'Back to home';

  @override
  String get categoryTravel => 'Travel';

  @override
  String get categoryFamily => 'Family';

  @override
  String get categoryRelationships => 'Relationships';

  @override
  String get categoryCelebrations => 'Celebrations';

  @override
  String get categoryEducation => 'Education';

  @override
  String get categoryCareer => 'Career';

  @override
  String get categoryHome => 'Home';

  @override
  String get categoryDaily => 'Daily Life';

  @override
  String get settingsAppearance => 'Appearance';

  @override
  String get settingsThemeSystem => 'System';

  @override
  String get settingsThemeLight => 'Light';

  @override
  String get settingsThemeDark => 'Dark';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsLanguageSystem => 'System language';

  @override
  String get settingsNotifications => 'Notifications';

  @override
  String get settingsPrivacy => 'Privacy & Security';

  @override
  String get settingsBackup => 'Backup Status';

  @override
  String get settingsStorage => 'Storage Usage';
}

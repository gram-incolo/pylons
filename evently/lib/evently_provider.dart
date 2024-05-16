import 'dart:async';
import 'package:dartz/dartz.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:evently/generated/locale_keys.g.dart';
import 'package:evently/main.dart';
import 'package:evently/models/denom.dart';
import 'package:evently/models/events.dart';
import 'package:evently/models/picked_file_model.dart';
import 'package:evently/models/storage_response_model.dart';
import 'package:evently/repository/repository.dart';
import 'package:evently/screens/event_hub/event_hub_screen.dart';
import 'package:evently/screens/event_hub/event_hub_view_model.dart';
import 'package:evently/utils/constants.dart';
import 'package:evently/utils/extension_util.dart';
import 'package:evently/utils/failure/failure.dart';
import 'package:evently/widgets/loading_with_progress.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';
import 'package:pylons_sdk/low_level.dart';

import 'services/third_party_services/quick_node.dart';

@LazySingleton()
class EventlyProvider extends ChangeNotifier {
  EventlyProvider({
    required this.repository,
  });

  final Repository repository;

  ///* overview screen variable
  String _eventName = '';
  String _hostName = '';
  String? _thumbnail;
  bool _isOverviewEnable = false;

  String? get thumbnail => _thumbnail;
  String get eventName => _eventName;
  String get hostName => _hostName;
  bool get isOverviewEnable => _isOverviewEnable;

  set setEventName(String value) {
    _eventName = value;
    checkIsOverEnable();
    notifyListeners();
  }

  set setHostName(String value) {
    _hostName = value;
    checkIsOverEnable();
    notifyListeners();
  }

  set setThumbnail(String? file) {
    _thumbnail = file;
    checkIsOverEnable();
    notifyListeners();
  }

  set setOverviewEnable(bool value) {
    _isOverviewEnable = value;
    notifyListeners();
  }

  checkIsOverEnable() {
    setOverviewEnable = thumbnail != null && eventName.length >= kMinEventName && hostName.length >= kMinHostName;
  }

  ///* detail screen
  String _startDate = "";
  String _endDate = "";
  String _startTime = "";
  String _endTime = "";
  String _location = "";
  String _description = "";

  String get startDate => _startDate;
  String get endDate => _endDate;
  String get startTime => _startTime;
  String get endTime => _endTime;
  String get location => _location;
  String get description => _description;

  set setStartDate(String value) {
    _startDate = value;
    notifyListeners();
  }

  set setEndDate(String value) {
    _endDate = value;
    notifyListeners();
  }

  set setStartTime(String value) {
    _startTime = value;
    notifyListeners();
  }

  set setEndTime(String value) {
    _endTime = value;
    notifyListeners();
  }

  set setLocation(String value) {
    _location = value;
    notifyListeners();
  }

  set setDescription(String value) {
    _description = value;
    notifyListeners();
  }

  /// perks screen
  final List<PerksModel> _perks = [];
  int _selectedPerk = 0;

  List<PerksModel> get perks => _perks;

  int get selectedPerk => _selectedPerk;

  set setSelectedPerks(int val) {
    _selectedPerk = val;
    notifyListeners();
  }

  set setPerks(PerksModel perksModel) {
    _perks.add(perksModel);
    notifyListeners();
  }

  updatePerks(PerksModel perksModel, int index) {
    _perks[index] = perksModel;
    notifyListeners();
  }

  removePerks(int index) {
    _perks.removeAt(index);
    notifyListeners();
  }

  ///* price screen

  Denom _selectedDenom = Denom.availableDenoms.first;

  Denom get selectedDenom => _selectedDenom;

  List<Denom> supportedDenomList = Denom.availableDenoms;

  FreeDrop _isFreeDrop = FreeDrop.unselected;

  int _numberOfTickets = 0;
  int _price = 0;

  set setNumberOfTickets(int numberOfTickets) {
    _numberOfTickets = numberOfTickets;
    notifyListeners();
  }

  int get numberOfTickets => _numberOfTickets;

  FreeDrop get isFreeDrop => _isFreeDrop;

  set setFreeDrop(FreeDrop freeDrop) {
    _isFreeDrop = freeDrop;
    notifyListeners();
  }

  set setPrice(int price) {
    _price = price;
    notifyListeners();
  }

  int get price => _price;

  void setSelectedDenom(Denom value) {
    _selectedDenom = value;
    notifyListeners();
  }

  final StreamController<UploadProgress> _uploadProgressController = StreamController.broadcast();

  Stream<UploadProgress> get uploadProgressStream => _uploadProgressController.stream;

  void pickThumbnail() async {
    final pickedFile = await repository.pickFile();

    final result = pickedFile.getOrElse(
      () => PickedFileModel(
        path: "",
        fileName: "",
        extension: "",
      ),
    );

    if (result.path.isEmpty) return;

    final loading = LoadingProgress()..showLoadingWithProgress(message: LocaleKeys.uploading.tr());

    Either<Failure, StorageResponseModel> response;
    response = await repository.uploadFileUsingQuickNode(
      uploadIPFSInput: UploadIPFSInput(fileName: result.fileName, filePath: result.path, contentType: QuickNode.getContentType(result.extension)),
      onUploadProgressCallback: (value) {
        _uploadProgressController.sink.add(value);
      },
    );

    if (response.isLeft()) {
      loading.dismiss();
      LocaleKeys.something_wrong_while_uploading.tr().show();
      return;
    }
    final fileUploadResponse = response.getOrElse(() => StorageResponseModel.initial());
    loading.dismiss();

    setThumbnail = "$ipfsDomain/${fileUploadResponse.value?.cid}";
  }

  String currentUserName = "";
  bool stripeAccountExists = false;

  String? _cookbookId;
  String? get cookbookId => _cookbookId;

  bool showStripeDialog() => !stripeAccountExists && _selectedDenom.symbol == kUsdSymbol && isFreeDrop == FreeDrop.no;

  ///* this method is used to get the profile
  Future<SDKIPCResponse<Profile>> getProfile() async {
    final sdkResponse = await PylonsWallet.instance.getProfile();

    if (sdkResponse.success) {
      currentUserName = sdkResponse.data!.username;
      stripeAccountExists = sdkResponse.data!.stripeExists;

      supportedDenomList = Denom.availableDenoms.where((Denom e) => sdkResponse.data!.supportedCoins.contains(e.symbol)).toList();

      if (supportedDenomList.isNotEmpty && selectedDenom.symbol.isEmpty) {
        _selectedDenom = supportedDenomList.first;
      }
    }
    return sdkResponse;
  }

  String _recipeId = "";
  String get recipeId => _recipeId;

  Future<bool> createRecipe() async {
    final scaffoldMessengerState = navigatorKey.getState();

    final isCookBookCreated = await createCookbook();

    if (isCookBookCreated) {
      _recipeId = repository.autoGenerateEventlyId();

      final event = Events(
        eventName: eventName,
        hostName: hostName,
        thumbnail: thumbnail!,
        startDate: startDate,
        endDate: endDate,
        startTime: startTime,
        endTime: endTime,
        location: location,
        description: description,
        numberOfTickets: numberOfTickets.toString(),
        price: price.toString(),
        listOfPerks: perks.join(','),
        cookbookID: _cookbookId!,
        recipeID: _recipeId,
      );

      final recipe = event.createRecipe(
        cookbookId: _cookbookId!,
        recipeId: _recipeId,
        isFreeDrop: isFreeDrop,
        symbol: selectedDenom.symbol,
        perksList: perks,
        price: price.toString(),
      );

      final response = await PylonsWallet.instance.txCreateRecipe(recipe, requestResponse: false);

      if (!response.success) {
        scaffoldMessengerState?.show(message: "$kErrRecipe ${response.error}");
        return false;
      }
      scaffoldMessengerState?.show(message: LocaleKeys.recipe_created.tr());
      final nftFromRecipe = Events.fromRecipe(recipe);
      GetIt.I.get<EventHubViewModel>().updatePublishedNFTList(nft: nftFromRecipe);
      deleteNft();
      return true;
    }

    return false;
  }

  Future<void> deleteNft() async {
    notifyListeners();
  }

  /// send createCookBook tx message to the wallet app
  /// return true or false depending on the response from the wallet app
  Future<bool> createCookbook() async {
    _cookbookId = await repository.autoGenerateCookbookId();

    final cookBook1 = Cookbook(
      creator: "",
      id: _cookbookId,
      name: cookbookName,
      description: cookbookDesc,
      developer: hostName,
      version: kVersionCookboox,
      supportEmail: supportedEmail,
      enabled: true,
    );

    final response = await PylonsWallet.instance.txCreateCookbook(cookBook1);
    if (response.success) {
      return true;
    }

    navigatorKey.showMsg(message: response.error);
    return false;
  }
}

import 'package:flutter/material.dart';

/// Alttan açılan panelleri tek yerden açar (şartname 29. bölüm).
///
/// Uygulamadaki her panel aynı üç şeye ihtiyaç duyuyor:
///
/// - `isScrollControlled` — panel içeriği kadar yer kaplasın, ekranın
///   yarısına sıkışmasın.
/// - `useSafeArea` — üstteki çentiğin altına girmesin.
/// - **Alttaki sistem çubuğu payı.** `useSafeArea` bunu yapmaz; yalnızca
///   üstü halleder. Alt taraf panelin kendi sorumluluğudur.
///
/// Üçüncüsü gözden kaçınca gerçek cihazda görünen hata şu: üç tuşlu
/// gezinme çubuğu olan telefonlarda (Samsung'ların çoğu) panelin en
/// altındaki düğmeler tuşların arkasında kalıyor ve dokunulamıyor.
/// Emülatörde jest çubuğu ince olduğu için fark edilmiyordu.
///
/// Panelleri doğrudan `showModalBottomSheet` ile açmak yerine buradan
/// açmak, bu üçünün bir daha unutulmamasını sağlar.
Future<T?> showAppSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (BuildContext context) => _SheetInsets(child: builder(context)),
  );
}

/// Panelin altına sistem çubuğu ve klavye payı bırakır.
class _SheetInsets extends StatelessWidget {
  const _SheetInsets({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final MediaQueryData media = MediaQuery.of(context);

    return Padding(
      // İki boşluk toplanır ama çakışmaz: klavye açıldığında sistem çubuğu
      // klavyenin arkasında kalır ve [MediaQueryData.padding] kendiliğinden
      // sıfırlanır — viewPadding kullanılsaydı pay iki kez eklenirdi.
      padding: EdgeInsets.only(
        bottom: media.viewInsets.bottom + media.padding.bottom,
      ),
      child: child,
    );
  }
}

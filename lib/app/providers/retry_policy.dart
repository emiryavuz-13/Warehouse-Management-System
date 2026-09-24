/// Provider'ların hata sonrası yeniden deneme davranışı.
///
/// **Neden gerekli:** Riverpod 3, başarısız olan bir provider'ı varsayılan
/// olarak 10 kez, üstel geri çekilmeyle yeniden dener (200ms, 400ms, 800ms …
/// 6.4s). Hatanın kullanıcıya ulaşması yaklaşık 38 saniye sürer. Bu süre
/// boyunca ekran yükleniyor durumunda kalır — kullanıcı donmuş bir arayüz
/// görür.
///
/// Varsayılan politika yalnızca `Error` ve `ProviderException` türlerini
/// muaf tutar; iş kuralı hatalarımız (`WarehouseException`) `Exception`
/// olduğu için tam olarak bu tuzağa düşer.
///
/// **Bu uygulamada yeniden deneme anlamsız:** veri tamamen yerelde ve
/// senkron. Bir okuma başarısız olduysa nedeni ya hata simülasyonudur ya da
/// gerçek bir program hatası; ikisi de tekrar denemekle düzelmez.
/// Şartname 25. bölüm hata durumunun kullanıcıya **gösterilmesini** istiyor,
/// arkada saklanmasını değil.
///
/// Gerçek API'ye geçildiğinde burası ağ hataları için makul bir politikayla
/// değiştirilebilir; tek bir dosya yeterlidir.
library;

/// Hiçbir zaman yeniden deneme: hata anında yüzeye çıkar.
///
/// `null` döndürmek Riverpod'a "tekrar deneme" demektir.
Duration? noRetryPolicy(int retryCount, Object error) => null;

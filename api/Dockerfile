# İZ API — çok aşamalı imaj.
#
# NEDEN ÇOK AŞAMALI?
# SDK imajı ~800 MB, çalışma zamanı imajı ~110 MB. Derlemeyi ilkinde yapıp
# yalnız çıktıyı ikincisine taşıyoruz: küçük imaj, hızlı dağıtım, küçük
# saldırı yüzeyi (derleyici üretimde durmaz).
#
# BARINDIRMADAN BAĞIMSIZ: yapılandırma tamamen ortam değişkeninden geliyor
# ve uygulama diske yazmıyor. Aynı imaj kiralık bir VPS'te de yönetilen bir
# konteyner servisinde de çalışır — barındırma kararı ertelenebilir kalıyor
# (bkz. ADR-B11).

# --- 1) Derleme -----------------------------------------------------------
FROM mcr.microsoft.com/dotnet/sdk:9.0 AS build
WORKDIR /kaynak

# Önce yalnız proje dosyaları: bağımlılıklar değişmedikçe restore katmanı
# önbellekten gelir. Kaynak kodu baştan kopyalasaydık her değişiklikte
# yeniden restore ederdik.
COPY Directory.Build.props Iz.sln ./
COPY src/Iz.Domain/Iz.Domain.csproj                 src/Iz.Domain/
COPY src/Iz.Application/Iz.Application.csproj       src/Iz.Application/
COPY src/Iz.Infrastructure/Iz.Infrastructure.csproj src/Iz.Infrastructure/
COPY src/Iz.Api/Iz.Api.csproj                       src/Iz.Api/
COPY tests/Iz.UnitTests/Iz.UnitTests.csproj                 tests/Iz.UnitTests/
COPY tests/Iz.IntegrationTests/Iz.IntegrationTests.csproj   tests/Iz.IntegrationTests/
RUN dotnet restore

COPY . .
RUN dotnet publish src/Iz.Api/Iz.Api.csproj -c Release -o /uygulama --no-restore

# --- 2) Çalışma zamanı ----------------------------------------------------
FROM mcr.microsoft.com/dotnet/aspnet:9.0 AS runtime
WORKDIR /uygulama

# Root olarak çalışmıyoruz. Konteyner kaçışı senaryosunda root ayrıcalığı
# devretmenin bir gerekçesi yok.
RUN useradd --uid 10001 --create-home --shell /usr/sbin/nologin iz
USER 10001

COPY --from=build --chown=10001:10001 /uygulama .

# Sabit port: ters vekil sunucu (nginx/Caddy) veya platform bunu eşler.
ENV ASPNETCORE_HTTP_PORTS=8080
EXPOSE 8080

# HEALTHCHECK BİLİNÇLİ OLARAK YOK.
# İmajda curl/wget bulunmuyor ve sırf sağlık yoklaması için paket kurmak
# hem imajı hem saldırı yüzeyini büyütür. Yoklamayı platform HTTP üzerinden
# yapar — /health/live ve /health/ready uçları tam bunun için var.
# (Kubernetes, Cloud Run, Azure Container Apps ve nginx zaten böyle çalışır.)

ENTRYPOINT ["dotnet", "Iz.Api.dll"]

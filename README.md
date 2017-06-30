# Anak Pulau

> Mencari pulau pulau yang tersedia di wikipedia atau wikidata dan berada pada openstreetmap

## Installasi
Clone Repository
```sh
git clone https://github.com/Wikimedia-ID/anak-pulau.git && cd anak-pulau
```

Install dependency
```sh
gem install bundler && bundle install
```

## Penggunaan
```sh
ruby app.rb "Nama Lokasi Adminstratif"
```
### Contoh
```sh
ruby app.rb "Bali"
```

## Output
Output File akan tersimpan di  `results/"Nama Lokasi Adminstratif"_islands.json` dan `results/"Nama Lokasi Adminstratif"_islads.csv`

Untuk contoh penggunaan pada wilayah `Bali`, hasilnya akan berada pada:

```
results/Bali_islands.json
```
dan
```
results/Bali_islands.csv
```

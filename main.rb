# frozen_string_literal: true

require 'json'
require 'fileutils'
require 'sketchup'
require 'extensions'

module FurnitureTools
  VERSION = "1.0.8" unless const_defined?(:VERSION)
  REMOTE_BASE_URL = "https://raw.githubusercontent.com/byurii94/furniture-tools/main" unless const_defined?(:REMOTE_BASE_URL)

  def self.parse_float(val)
    return val.to_f if val.is_a?(Numeric)
    val.to_s.tr(',', '.').to_f
  end

  def self.parse_int(val)
    return val.to_i if val.is_a?(Numeric)
    val.to_s.tr(',', '.').to_i
  end

  def self.resolve_item_name(custom_name, default_name)
    cleaned = custom_name.to_s.strip
    cleaned.empty? ? default_name : cleaned
  end

  def self.version_newer?(remote, local)
    r_parts = remote.split('.').map(&:to_i)
    l_parts = local.split('.').map(&:to_i)
    (r_parts <=> l_parts) == 1
  end

  def self.check_for_updates(silent: true)
    url = "#{REMOTE_BASE_URL}/version.json?t=#{Time.now.to_i}"
    req = Sketchup::Http::Request.new(url, Sketchup::Http::GET)
    req.start do |_request, response|
      if response && response.status_code == 200
        begin
          data = JSON.parse(response.body)
          remote_ver = data["version"].to_s.strip
          if !remote_ver.empty? && version_newer?(remote_ver, VERSION)
            download_and_install_update(remote_ver)
          elsif !silent
            UI.messagebox("У вас уже встановлена актуальна версія (#{VERSION}).")
          end
        rescue => e
          UI.messagebox("Помилка перевірки оновлень: #{e.message}") unless silent
        end
      elsif !silent
        UI.messagebox("Не вдалося з'єднатися із сервером оновлень (код: #{response ? response.status_code : 'немає відповіді'}).")
      end
    end
  end

  def self.download_and_install_update(new_version)
    plugin_dir = File.dirname(__FILE__)
    files = [
      "main.rb",
      "dialog.html",
      "images/shelf_16.png",
      "images/shelf_24.png",
      "images/facade_16.png",
      "images/facade_24.png"
    ]
    optional_files = [
      "dialog.html",
      "images/shelf_16.png",
      "images/shelf_24.png",
      "images/facade_16.png",
      "images/facade_24.png"
    ]
    downloaded = {}
    pending = files.length
    failed = false

    files.each do |fname|
      url = "#{REMOTE_BASE_URL}/#{fname}?t=#{Time.now.to_i}"
      file_req = Sketchup::Http::Request.new(url, Sketchup::Http::GET)
      file_req.start do |_r, resp|
        next if failed
        if resp && resp.status_code == 200 && !resp.body.to_s.empty?
          downloaded[fname] = resp.body
        elsif optional_files.include?(fname) && resp && resp.status_code == 404
          # Пропускаємо, якщо опціонального файлу ще немає в репозиторії
        else
          failed = true
          UI.messagebox("Не вдалося завантажити файл #{fname} (код: #{resp ? resp.status_code : 'немає відповіді'}).")
        end

        pending -= 1
        if pending == 0 && !failed
          downloaded.each do |name, content|
            target_path = File.join(plugin_dir, name)
            FileUtils.mkdir_p(File.dirname(target_path))
            File.binwrite(target_path, content)
          end
          UI.messagebox(
            "Меблеві калькулятори оновлено до версії #{new_version}!\n" \
            "Перезапустіть SketchUp, щоб зміни набули чинності."
          )
        end
      end
    end
  end

  # Єдиний інтерфейс у стилі вікна фасадів для обох інструментів (mode: "shelves" | "facades")
  def self.build_dialog_html
    <<~HTML
      <!DOCTYPE html>
      <html lang="uk">
      <head>
        <meta charset="UTF-8">
        <style>
          body {
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
            font-size: 13px;
            margin: 12px;
            color: #1f2937;
            background: #f9fafb;
          }
          .card {
            background: #fff;
            border: 1px solid #e5e7eb;
            border-radius: 8px;
            padding: 10px 12px;
            margin-bottom: 10px;
          }
          .badge {
            display: inline-block;
            background: #eff6ff;
            color: #1d4ed8;
            border: 1px solid #bfdbfe;
            border-radius: 6px;
            padding: 4px 8px;
            font-weight: 600;
            margin-bottom: 6px;
          }
          .meta {
            font-size: 12px;
            color: #4b5563;
          }
          .grid-2 {
            display: grid;
            grid-template-columns: 1fr 1fr;
            gap: 8px;
          }
          label {
            display: block;
            font-size: 11px;
            color: #374151;
            margin-bottom: 3px;
            font-weight: 600;
          }
          input[type="number"], input[type="text"] {
            width: 100%;
            box-sizing: border-box;
            padding: 6px 8px;
            border: 1px solid #d1d5db;
            border-radius: 6px;
            font-size: 13px;
          }
          .row-facade {
            display: grid;
            grid-template-columns: 78px 1fr 1.2fr;
            align-items: center;
            gap: 6px;
            margin-bottom: 6px;
          }
          .row-shelf-gap {
            display: grid;
            grid-template-columns: 96px 1fr;
            align-items: center;
            gap: 6px;
            margin-bottom: 6px;
          }
          .row-shelf-name {
            display: grid;
            grid-template-columns: 96px 1fr;
            align-items: center;
            gap: 6px;
            margin-bottom: 6px;
          }
          .row-label {
            font-size: 12px;
            font-weight: 600;
            white-space: nowrap;
          }
          .hint {
            font-size: 11px;
            color: #6b7280;
            margin-top: 4px;
          }
          .hidden {
            display: none;
          }
          .btn-apply {
            width: 100%;
            padding: 9px 12px;
            background: #2563eb;
            color: #fff;
            border: none;
            border-radius: 8px;
            font-size: 14px;
            font-weight: 600;
            cursor: pointer;
          }
          .btn-apply:hover {
            background: #1d4ed8;
          }
        </style>
      </head>
      <body>
        <div class="card">
          <div class="badge" id="dirBadge">Напрямок</div>
          <div class="meta" id="boxDims">Основа: —</div>
        </div>

        <div class="card">
          <div class="grid-2">
            <div>
              <label id="lblThickness">Товщина (мм)</label>
              <input type="number" id="thickness" step="0.5" min="1" value="18">
            </div>
            <div>
              <label id="lblCount">Кількість (шт.)</label>
              <input type="number" id="num_items" step="1" min="1" max="30" value="3">
            </div>
          </div>

          <div class="grid-2 hidden" id="facadeGapsGrid" style="margin-top: 8px;">
            <div>
              <label>Між фасадами (мм)</label>
              <input type="number" id="gap_between" step="0.5" min="0" value="3">
            </div>
            <div>
              <label>Зліва / спереду (мм)</label>
              <input type="number" id="gap_left" step="0.5" min="0" value="2">
            </div>
            <div>
              <label>Справа / ззаду (мм)</label>
              <input type="number" id="gap_right" step="0.5" min="0" value="2">
            </div>
            <div>
              <label>Зверху (мм)</label>
              <input type="number" id="gap_top" step="0.5" min="0" value="2">
            </div>
            <div>
              <label>Знизу (мм)</label>
              <input type="number" id="gap_bottom" step="0.5" min="0" value="2">
            </div>
          </div>
        </div>

        <div class="card hidden" id="shelfGapsCard">
          <label>Проміжки між полицями / краями (мм)</label>
          <div id="shelfGapsContainer"></div>
        </div>

        <div class="card">
          <label id="itemsCardLabel">Розміри та назви елементів</label>
          <div id="itemsContainer"></div>
          <div class="hint" id="itemsHint">Якщо назву не вводити, залишиться стандартна назва.</div>
        </div>

        <button class="btn-apply" id="applyBtn">Створити</button>

        <script>
          let currentMode = 'facades';
          let currentFixed = [];
          let currentGaps = [];
          let currentNames = [];

          function notifyRuby(action, payloadObj) {
            window.location = 'skp:' + action + '@' + encodeURIComponent(JSON.stringify(payloadObj));
          }

          function buildPayload() {
            const count = Math.max(1, parseInt(document.getElementById('num_items').value, 10) || 1);
            const names = Array.from(document.querySelectorAll('.name-input')).map((el) => el.value);
            currentNames = names;

            if (currentMode === 'facades') {
              const fixedInputs = document.querySelectorAll('.fixed-input');
              const fixedSizes = [];
              for (let i = 0; i < count; i++) {
                const rawFixed = fixedInputs[i] ? fixedInputs[i].value.trim() : '';
                fixedSizes.push(rawFixed === '' ? null : parseFloat(rawFixed));
              }
              currentFixed = fixedSizes;

              return {
                thickness: parseFloat(document.getElementById('thickness').value) || 18,
                num_facades: count,
                gap_between: parseFloat(document.getElementById('gap_between').value) || 0,
                gap_left: parseFloat(document.getElementById('gap_left').value) || 0,
                gap_right: parseFloat(document.getElementById('gap_right').value) || 0,
                gap_top: parseFloat(document.getElementById('gap_top').value) || 0,
                gap_bottom: parseFloat(document.getElementById('gap_bottom').value) || 0,
                fixed_sizes: fixedSizes,
                custom_names: names
              };
            } else {
              const gapInputs = document.querySelectorAll('.shelf-gap-input');
              const gaps = [];
              for (let i = 0; i < count + 1; i++) {
                gaps.push(parseFloat(gapInputs[i] ? gapInputs[i].value : 0) || 0);
              }
              currentGaps = gaps;

              return {
                thickness: parseFloat(document.getElementById('thickness').value) || 18,
                num_items: count,
                gaps: gaps,
                custom_names: names
              };
            }
          }

          function renderShelfGaps(count, gapsArr) {
            const container = document.getElementById('shelfGapsContainer');
            container.innerHTML = '';
            for (let i = 0; i < count + 1; i++) {
              const row = document.createElement('div');
              row.className = 'row-shelf-gap';

              const lbl = document.createElement('span');
              lbl.className = 'row-label';
              lbl.textContent = 'Проміжок ' + (i + 1) + ':';

              const inp = document.createElement('input');
              inp.type = 'number';
              inp.step = '0.5';
              inp.min = '0';
              inp.className = 'shelf-gap-input';
              inp.value = (gapsArr && gapsArr[i] !== undefined) ? gapsArr[i] : 0;
              inp.addEventListener('input', () => notifyRuby('update_params', buildPayload()));

              row.appendChild(lbl);
              row.appendChild(inp);
              container.appendChild(row);
            }
          }

          function renderItems(mode, count, fixedArr, namesArr) {
            const container = document.getElementById('itemsContainer');
            container.innerHTML = '';

            for (let i = 0; i < count; i++) {
              const row = document.createElement('div');
              row.className = mode === 'facades' ? 'row-facade' : 'row-shelf-name';

              const lbl = document.createElement('span');
              lbl.className = 'row-label';
              lbl.textContent = (mode === 'facades' ? 'Фасад ' : 'Елемент ') + (i + 1) + ':';

              const nameInp = document.createElement('input');
              nameInp.type = 'text';
              nameInp.placeholder = 'Назва (авто)';
              nameInp.className = 'name-input';
              if (namesArr && namesArr[i] !== null && namesArr[i] !== undefined) {
                nameInp.value = namesArr[i];
              }
              nameInp.addEventListener('input', () => notifyRuby('update_params', buildPayload()));

              row.appendChild(lbl);

              if (mode === 'facades') {
                const fixedInp = document.createElement('input');
                fixedInp.type = 'number';
                fixedInp.step = '0.1';
                fixedInp.min = '1';
                fixedInp.placeholder = 'Авто мм';
                fixedInp.className = 'fixed-input';
                if (fixedArr && fixedArr[i] !== null && fixedArr[i] !== undefined) {
                  fixedInp.value = fixedArr[i];
                }
                fixedInp.addEventListener('input', () => notifyRuby('update_params', buildPayload()));
                row.appendChild(fixedInp);
              }

              row.appendChild(nameInp);
              container.appendChild(row);
            }
          }

          function initDialog(data) {
            currentMode = data.mode || 'facades';

            if (currentMode === 'facades') {
              document.getElementById('dirBadge').textContent = data.axis_label + ' • ' + data.direction_label;
              document.getElementById('boxDims').textContent =
                'Основа: ' + data.width + ' × ' + data.depth + ' × ' + data.height + ' мм';
              document.getElementById('lblThickness').textContent = 'Товщина фасаду (мм)';
              document.getElementById('lblCount').textContent = 'Кількість фасадів (шт.)';
              document.getElementById('facadeGapsGrid').classList.remove('hidden');
              document.getElementById('shelfGapsCard').classList.add('hidden');
              document.getElementById('itemsCardLabel').textContent =
                'Фіксовані розміри (мм, пусто = авто) та свої назви (пусто = стандарт)';
              document.getElementById('itemsHint').textContent =
                'Якщо вказати розмір для частини фасадів, залишок розподілиться порівну; порожня назва = стандартна.';
              document.getElementById('applyBtn').textContent = 'Створити фасади';

              document.getElementById('thickness').value = data.thickness;
              document.getElementById('num_items').value = data.num_facades;
              document.getElementById('gap_between').value = data.gap_between;
              document.getElementById('gap_left').value = data.gap_left;
              document.getElementById('gap_right').value = data.gap_right;
              document.getElementById('gap_top').value = data.gap_top;
              document.getElementById('gap_bottom').value = data.gap_bottom;

              currentFixed = data.fixed_sizes || [];
              currentNames = data.custom_names || [];
              renderItems('facades', data.num_facades, currentFixed, currentNames);
            } else {
              document.getElementById('dirBadge').textContent = data.axis_label;
              document.getElementById('boxDims').textContent =
                'Ніша: ' + data.width + ' × ' + data.depth + ' × ' + data.height + ' мм (вісь: ' + data.axis_length + ' мм)';
              document.getElementById('lblThickness').textContent = 'Товщина матеріалу (мм)';
              document.getElementById('lblCount').textContent = 'Кількість елементів (шт.)';
              document.getElementById('facadeGapsGrid').classList.add('hidden');
              document.getElementById('shelfGapsCard').classList.remove('hidden');
              document.getElementById('itemsCardLabel').textContent =
                'Свої назви полиць / перегородок (пусто = стандарт)';
              document.getElementById('itemsHint').textContent =
                'Якщо назву не вводити, буде використано стандартну назву («Полиця 1» або «Перегородка 1»).';
              document.getElementById('applyBtn').textContent = 'Створити полиці / перегородки';

              document.getElementById('thickness').value = data.thickness;
              document.getElementById('num_items').value = data.num_items;

              currentGaps = data.gaps || [];
              currentNames = data.custom_names || [];
              renderShelfGaps(data.num_items, currentGaps);
              renderItems('shelves', data.num_items, [], currentNames);
            }
          }

          ['thickness', 'num_items', 'gap_between', 'gap_left', 'gap_right', 'gap_top', 'gap_bottom'].forEach((id) => {
            const el = document.getElementById(id);
            if (!el) return;
            el.addEventListener('input', () => {
              if (id === 'num_items') {
                const count = Math.max(1, parseInt(el.value, 10) || 1);
                if (currentMode === 'facades') {
                  renderItems('facades', count, currentFixed, currentNames);
                } else {
                  renderShelfGaps(count, currentGaps);
                  renderItems('shelves', count, [], currentNames);
                }
              }
              notifyRuby('update_params', buildPayload());
            });
          });

          document.getElementById('applyBtn').addEventListener('click', () => {
            notifyRuby('apply', buildPayload());
          });

          document.addEventListener('DOMContentLoaded', () => {
            window.location = 'skp:ready@';
          });
        </script>
      </body>
      </html>
    HTML
  end
end

module ShelfCalculator
  class ShelfEdgeTool
    def initialize(group, dims_mm)
      @group = group
      @bb = group&.bounds
      @dims_mm = dims_mm
      @hover_axis = nil
      @hover_edge_pts = nil
      @selected_axis = nil
      @dialog = nil
      @gaps_mm = []
      @generated = false
      @prev_transparency = nil
      @params = {
        thickness: 18.0,
        num_items: 4,
        custom_names: Array.new(4, "")
      }
    end

    def activate
      @selected_axis = nil
      @hover_axis = nil
      @hover_edge_pts = nil
      @generated = false

      opts = Sketchup.active_model.rendering_options
      @prev_transparency = opts["ModelTransparency"]
      opts["ModelTransparency"] = true

      Sketchup.set_status_text("🪵 КАЛЬКУЛЯТОР ПОЛИЦЬ | Наведіть курсор на ребро боксу та клікніть, щоб обрати напрямок розбиття | ESC = Вихід")
      Sketchup.active_model.active_view&.invalidate
    end

    def deactivate(view)
      close_dialog
      unless @prev_transparency.nil?
        Sketchup.active_model.rendering_options["ModelTransparency"] = @prev_transparency
        @prev_transparency = nil
      end
      view.invalidate if view
    end

    def onKeyDown(key, repeat, flags, view)
      if key == 27
        close_dialog
        Sketchup.active_model.select_tool(nil)
      end
    end

    def onMouseMove(flags, x, y, view)
      return if @selected_axis
      return unless @group && @group.valid? && @bb

      ip = view.inputpoint(x, y)
      edge = ip.edge

      if edge && edge_belongs_to_group?(edge, @group)
        tr = @group.transformation
        p1 = edge.start.position.transform(tr)
        p2 = edge.end.position.transform(tr)
        vec = p2 - p1

        if vec.length > 1e-6
          @hover_axis = vector_to_axis(vec.normalize)
          @hover_edge_pts = [p1, p2]
          Sketchup.set_status_text("🪵 Ребро вздовж осі [ #{axis_label(@hover_axis)} ] (#{axis_length_mm(@hover_axis).round(1)} мм) — клікніть для налаштувань | ESC = Вихід")
          view.invalidate
          return
        end
      end

      @hover_axis = nil
      @hover_edge_pts = nil
      Sketchup.set_status_text("🪵 Наведіть курсор на ребро виділеного боксу та клікніть | ESC = Вихід")
      view.invalidate
    end

    def onLButtonDown(flags, x, y, view)
      return if @selected_axis
      return unless @hover_axis

      @selected_axis = @hover_axis
      @params = {
        thickness: 18.0,
        num_items: 4,
        custom_names: Array.new(4, "")
      }
      @gaps_mm = default_equal_gaps(axis_length_mm(@selected_axis), @params[:num_items], @params[:thickness])
      open_dialog
      view.invalidate
    end

    def draw(view)
      return unless @bb && @group&.valid?

      if @selected_axis.nil? && @hover_edge_pts && @hover_edge_pts.length == 2
        view.drawing_color = Sketchup::Color.new(40, 185, 65)
        view.line_width = 8
        view.draw(GL_LINES, @hover_edge_pts)
        return
      end

      return unless @selected_axis
      return unless valid_layout?

      view.drawing_color = Sketchup::Color.new(0, 120, 215)
      view.line_width = 2
      points = []

      start_x = @bb.min.x
      start_y = @bb.min.y
      start_z = @bb.min.z

      w_mm = @dims_mm[:width]
      d_mm = @dims_mm[:depth]
      h_mm = @dims_mm[:height]
      t_mm = @params[:thickness]

      case @selected_axis
      when :z
        cursor_z = @gaps_mm[0]
        @params[:num_items].times do |i|
          z0 = start_z + cursor_z.mm
          z1 = z0 + t_mm.mm
          points.concat(box_wireframe_points(
            start_x, start_y, z0,
            start_x + w_mm.mm, start_y + d_mm.mm, z1
          ))
          cursor_z += t_mm + @gaps_mm[i + 1]
        end

      when :x
        cursor_x = @gaps_mm[0]
        @params[:num_items].times do |i|
          x0 = start_x + cursor_x.mm
          x1 = x0 + t_mm.mm
          points.concat(box_wireframe_points(
            x0, start_y, start_z,
            x1, start_y + d_mm.mm, start_z + h_mm.mm
          ))
          cursor_x += t_mm + @gaps_mm[i + 1]
        end

      when :y
        cursor_y = @gaps_mm[0]
        @params[:num_items].times do |i|
          y0 = start_y + cursor_y.mm
          y1 = y0 + t_mm.mm
          points.concat(box_wireframe_points(
            start_x, y0, start_z,
            start_x + w_mm.mm, y1, start_z + h_mm.mm
          ))
          cursor_y += t_mm + @gaps_mm[i + 1]
        end
      end

      view.draw(GL_LINES, points) unless points.empty?
    end

    private

    def edge_belongs_to_group?(edge, group)
      return false unless edge.parent.is_a?(Sketchup::ComponentDefinition)
      group.entities.grep(Sketchup::Edge).include?(edge)
    end

    def vector_to_axis(vec)
      ax = vec.x.abs
      ay = vec.y.abs
      az = vec.z.abs
      if az >= ax && az >= ay
        :z
      elsif ax >= ay && ax >= az
        :x
      else
        :y
      end
    end

    def axis_label(axis)
      case axis
      when :z then "ВИСОТА (Z — горизонтальні полиці)"
      when :x then "ШИРИНА (X — перегородки по ширині)"
      when :y then "ГЛИБИНА (Y — перегородки по глибині)"
      else ""
      end
    end

    def axis_length_mm(axis)
      case axis
      when :z then @dims_mm[:height]
      when :x then @dims_mm[:width]
      when :y then @dims_mm[:depth]
      else 0.0
      end
    end

    def default_equal_gaps(total_len, num_items, thickness)
      num_gaps = num_items + 1
      free_len = total_len - (num_items * thickness)
      each_gap = free_len / num_gaps.to_f
      Array.new(num_gaps) { each_gap.round(2) }
    end

    def valid_layout?
      return false unless @group && @group.valid?
      n = @params[:num_items]
      t = @params[:thickness]
      return false if n <= 0 || t <= 0
      return false unless @gaps_mm.is_a?(Array) && @gaps_mm.length == n + 1
      return false if @gaps_mm.any? { |g| g.nil? || g < 0 }

      total_used = (n * t) + @gaps_mm.sum
      total_len = axis_length_mm(@selected_axis)
      total_used <= total_len + 0.01
    end

    def box_wireframe_points(x0, y0, z0, x1, y1, z1)
      p1 = Geom::Point3d.new(x0, y0, z0)
      p2 = Geom::Point3d.new(x1, y0, z0)
      p3 = Geom::Point3d.new(x1, y1, z0)
      p4 = Geom::Point3d.new(x0, y1, z0)

      p5 = Geom::Point3d.new(x0, y0, z1)
      p6 = Geom::Point3d.new(x1, y0, z1)
      p7 = Geom::Point3d.new(x1, y1, z1)
      p8 = Geom::Point3d.new(x0, y1, z1)

      [
        p1, p2, p2, p3, p3, p4, p4, p1,
        p5, p6, p6, p7, p7, p8, p8, p5,
        p1, p5, p2, p6, p3, p7, p4, p8
      ]
    end

    def open_dialog
      close_dialog

      @dialog = UI::HtmlDialog.new(
        dialog_title: "Параметри полиць",
        preferences_key: "FurnitureToolsDialog",
        scrollable: true,
        resizable: true,
        width: 440,
        height: 680,
        style: UI::HtmlDialog::STYLE_DIALOG
      )

      @dialog.set_html(FurnitureTools.build_dialog_html)

      @dialog.add_action_callback("ready") do |_ctx|
        send_init_data
      end

      @dialog.add_action_callback("update_params") do |_ctx, json_str|
        apply_data_from_js(json_str)
        Sketchup.active_model.active_view&.invalidate
      end

      @dialog.add_action_callback("apply") do |_ctx, json_str|
        apply_data_from_js(json_str)
        if generate_shelves
          close_dialog
          Sketchup.active_model.select_tool(nil)
        end
      end

      @dialog.set_on_closed do
        @dialog = nil
        unless @generated
          Sketchup.active_model.select_tool(nil)
        end
      end

      @dialog.show
    end

    def apply_data_from_js(json_str)
      data = JSON.parse(json_str)
      n = [FurnitureTools.parse_int(data["num_items"]), 1].max
      @params[:thickness] = FurnitureTools.parse_float(data["thickness"])
      @params[:num_items] = n
      @gaps_mm = Array(data["gaps"]).map { |g| FurnitureTools.parse_float(g) }

      raw_names = Array(data["custom_names"])
      @params[:custom_names] = Array.new(n) { |i| raw_names[i].to_s }
    end

    def send_init_data
      return unless @dialog
      payload = {
        mode: "shelves",
        axis: @selected_axis.to_s,
        axis_label: axis_label(@selected_axis),
        axis_length: axis_length_mm(@selected_axis).round(2),
        width: @dims_mm[:width].round(2),
        depth: @dims_mm[:depth].round(2),
        height: @dims_mm[:height].round(2),
        thickness: @params[:thickness],
        num_items: @params[:num_items],
        gaps: @gaps_mm,
        custom_names: @params[:custom_names]
      }
      @dialog.execute_script("initDialog(#{payload.to_json});")
    end

    def close_dialog
      if @dialog
        dlg = @dialog
        @dialog = nil
        dlg.close
      end
    end

    def generate_shelves
      unless valid_layout?
        UI.messagebox("Перевірте розміри проміжків і товщину: сума перевищує розмір ніші або містить від'ємні значення.")
        return false
      end

      model = Sketchup.active_model
      entities = model.active_entities

      w_mm = @dims_mm[:width]
      d_mm = @dims_mm[:depth]
      h_mm = @dims_mm[:height]
      t_mm = @params[:thickness]
      n    = @params[:num_items]
      custom_names = @params[:custom_names] || []

      start_x = @bb.min.x
      start_y = @bb.min.y
      start_z = @bb.min.z

      model.start_operation("Створення полиць / перегородок", true)

      case @selected_axis
      when :z
        cursor_z = @gaps_mm[0]
        n.times do |i|
          shelf_group = entities.add_group
          shelf_group.name = FurnitureTools.resolve_item_name(custom_names[i], "Полиця #{i + 1}")
          shelf_group.transformation = Geom::Transformation.translation([start_x, start_y, start_z + cursor_z.mm])

          face = shelf_group.entities.add_face([0, 0, 0], [w_mm.mm, 0, 0], [w_mm.mm, d_mm.mm, 0], [0, d_mm.mm, 0])
          face.reverse! if face.normal.z < 0
          face.pushpull(t_mm.mm)

          cursor_z += t_mm + @gaps_mm[i + 1]
        end

      when :x
        cursor_x = @gaps_mm[0]
        n.times do |i|
          part_group = entities.add_group
          part_group.name = FurnitureTools.resolve_item_name(custom_names[i], "Перегородка #{i + 1}")
          part_group.transformation = Geom::Transformation.translation([start_x + cursor_x.mm, start_y, start_z])

          face = part_group.entities.add_face([0, 0, 0], [t_mm.mm, 0, 0], [t_mm.mm, d_mm.mm, 0], [0, d_mm.mm, 0])
          face.reverse! if face.normal.z < 0
          face.pushpull(h_mm.mm)

          cursor_x += t_mm + @gaps_mm[i + 1]
        end

      when :y
        cursor_y = @gaps_mm[0]
        n.times do |i|
          part_group = entities.add_group
          part_group.name = FurnitureTools.resolve_item_name(custom_names[i], "Перегородка #{i + 1}")
          part_group.transformation = Geom::Transformation.translation([start_x, start_y + cursor_y.mm, start_z])

          face = part_group.entities.add_face([0, 0, 0], [w_mm.mm, 0, 0], [w_mm.mm, t_mm.mm, 0], [0, t_mm.mm, 0])
          face.reverse! if face.normal.z < 0
          face.pushpull(h_mm.mm)

          cursor_y += t_mm + @gaps_mm[i + 1]
        end
      end

      entities.erase_entities(@group) if @group && @group.valid?
      model.commit_operation
      @generated = true
      true
    end
  end

  def self.calculate
    model = Sketchup.active_model
    selection = model.selection

    if selection.length != 1 || !selection[0].is_a?(Sketchup::Group)
      UI.messagebox("Будь ласка, виділіть один бокс-нішу (групу) у проєкті.")
      return
    end

    bb = selection[0].bounds
    dims_mm = {
      width:  (bb.max.x - bb.min.x).to_mm.to_f,
      depth:  (bb.max.y - bb.min.y).to_mm.to_f,
      height: (bb.max.z - bb.min.z).to_mm.to_f
    }

    tool = ShelfEdgeTool.new(selection[0], dims_mm)
    model.select_tool(tool)
  end
end

module FacadeCalculator
  class FacadeEdgeTool
    def initialize(group, dims_mm)
      @group = group
      @bb = group&.bounds
      @dims_mm = dims_mm
      @hover_edge_info = nil
      @selected_edge_info = nil
      @dialog = nil
      @generated = false
      @prev_transparency = nil
      @params = {
        thickness: 18.0,
        num_facades: 3,
        gap_between: 3.0,
        gap_left: 2.0,
        gap_right: 2.0,
        gap_top: 2.0,
        gap_bottom: 2.0,
        fixed_sizes: [nil, nil, nil],
        custom_names: Array.new(3, "")
      }
    end

    def activate
      @hover_edge_info = nil
      @selected_edge_info = nil
      @generated = false

      opts = Sketchup.active_model.rendering_options
      @prev_transparency = opts["ModelTransparency"]
      opts["ModelTransparency"] = true

      Sketchup.set_status_text("🗄️ КАЛЬКУЛЯТОР ФАСАДІВ | Наведіть курсор на вертикальне або горизонтальне ребро та клікніть | ESC = Вихід")
      Sketchup.active_model.active_view&.invalidate
    end

    def deactivate(view)
      close_dialog
      unless @prev_transparency.nil?
        Sketchup.active_model.rendering_options["ModelTransparency"] = @prev_transparency
        @prev_transparency = nil
      end
      view.invalidate if view
    end

    def onKeyDown(key, repeat, flags, view)
      if key == 27
        close_dialog
        Sketchup.active_model.select_tool(nil)
      end
    end

    def onMouseMove(flags, x, y, view)
      return if @selected_edge_info
      return unless @group && @group.valid? && @bb

      ip = view.inputpoint(x, y)
      edge = ip.edge

      if edge && edge_belongs_to_group?(edge, @group)
        info = analyze_edge(edge, @group)
        if info
          @hover_edge_info = info
          Sketchup.set_status_text("🗄️ Ребро вздовж осі [ #{info[:axis_label]} ] → #{direction_label(info[:direction])} — клікніть для налаштувань | ESC = Вихід")
          view.invalidate
          return
        end
      end

      @hover_edge_info = nil
      Sketchup.set_status_text("🗄️ Наведіть курсор на вертикальне або горизонтальне ребро боксу/площини та клікніть | ESC = Вихід")
      view.invalidate
    end

    def onLButtonDown(flags, x, y, view)
      return if @selected_edge_info
      return unless @hover_edge_info

      @selected_edge_info = @hover_edge_info
      normalize_item_arrays!
      open_dialog
      view.invalidate
    end

    def draw(view)
      return unless @bb && @group&.valid?

      if @selected_edge_info.nil? && @hover_edge_info
        pts = @hover_edge_info[:edge_pts]
        if pts && pts.length == 2
          view.drawing_color = Sketchup::Color.new(40, 185, 65)
          view.line_width = 8
          view.draw(GL_LINES, pts)
        end
        return
      end

      return unless @selected_edge_info

      boxes = compute_facade_boxes
      return if boxes.nil? || boxes.empty?

      view.drawing_color = Sketchup::Color.new(0, 120, 215)
      view.line_width = 2
      points = []

      boxes.each do |b|
        points.concat(box_wireframe_points(b[:x0], b[:y0], b[:z0], b[:x1], b[:y1], b[:z1]))
      end

      view.draw(GL_LINES, points) unless points.empty?
    end

    private

    def edge_belongs_to_group?(edge, group)
      return false unless edge.parent.is_a?(Sketchup::ComponentDefinition)
      group.entities.grep(Sketchup::Edge).include?(edge)
    end

    def analyze_edge(edge, group)
      tr = group.transformation
      p1 = edge.start.position.transform(tr)
      p2 = edge.end.position.transform(tr)
      vec = p2 - p1
      return nil if vec.length <= 1e-6

      n = vec.normalize
      ax = n.x.abs
      ay = n.y.abs
      az = n.z.abs

      w_mm = @dims_mm[:width]
      d_mm = @dims_mm[:depth]
      h_mm = @dims_mm[:height]

      plane = if d_mm < 0.5
                :front_back
              elsif w_mm < 0.5
                :left_right
              elsif h_mm < 0.5
                :horizontal
              else
                w_mm >= d_mm ? :front_back : :left_right
              end

      if az >= ax && az >= ay
        {
          axis: :z,
          axis_label: "ВИСОТА (Z)",
          plane: plane,
          direction: "Height",
          edge_pts: [p1, p2]
        }
      elsif ax >= ay && ax >= az
        p_use = (plane == :horizontal) ? :horizontal : :front_back
        {
          axis: :x,
          axis_label: "ШИРИНА (X)",
          plane: p_use,
          direction: "Width",
          edge_pts: [p1, p2]
        }
      else
        p_use = (plane == :horizontal) ? :horizontal_y : :left_right
        {
          axis: :y,
          axis_label: "ГЛИБИНА / ШИРИНА (Y)",
          plane: p_use,
          direction: "Width",
          edge_pts: [p1, p2]
        }
      end
    end

    def direction_label(dir)
      dir == "Height" ? "ПО ВИСОТІ (Шухляди)" : "ПО ШИРИНІ (Дверцята)"
    end

    def normalize_item_arrays!
      n = [@params[:num_facades].to_i, 1].max
      @params[:num_facades] = n

      arr_fixed = Array(@params[:fixed_sizes])
      @params[:fixed_sizes] = Array.new(n) do |i|
        val = arr_fixed[i]
        next nil if val.nil?
        f = FurnitureTools.parse_float(val)
        f > 0 ? f : nil
      end

      arr_names = Array(@params[:custom_names])
      @params[:custom_names] = Array.new(n) { |i| arr_names[i].to_s }
    end

    def calculate_segment_sizes(total_available_mm, num_facades, gap_between_mm, fixed_sizes)
      return nil if num_facades <= 0
      total_gaps = (num_facades - 1) * gap_between_mm
      net_span = total_available_mm - total_gaps
      return nil if net_span <= 0.0

      fixed_sum = 0.0
      free_indices = []

      num_facades.times do |i|
        f_val = fixed_sizes[i]
        if !f_val.nil? && f_val > 0.0
          fixed_sum += f_val
        else
          free_indices << i
        end
      end

      remainder = net_span - fixed_sum
      return nil if remainder < -0.01

      if free_indices.empty?
        return nil if (fixed_sum - net_span).abs > 0.5 && fixed_sum > net_span + 0.01
        return Array.new(num_facades) { |i| fixed_sizes[i].to_f }
      end

      return nil if remainder <= 0.0

      each_free = (remainder / free_indices.length.to_f).round(1)
      sizes = Array.new(num_facades, 0.0)
      assigned_sum = 0.0

      num_facades.times do |i|
        if !fixed_sizes[i].nil? && fixed_sizes[i] > 0.0
          sizes[i] = fixed_sizes[i].round(1)
        else
          sizes[i] = each_free
        end
        assigned_sum += sizes[i]
      end

      diff = (net_span - assigned_sum).round(1)
      last_free_idx = free_indices.last
      sizes[last_free_idx] = (sizes[last_free_idx] + diff).round(1)
      return nil if sizes.any? { |s| s <= 0.0 }

      sizes
    end

    def compute_facade_boxes
      return nil unless @selected_edge_info && @bb && @group&.valid?

      n = @params[:num_facades].to_i
      t = @params[:thickness].to_f
      return nil if n <= 0 || t <= 0.0

      gap_between = @params[:gap_between].to_f
      gap_left    = @params[:gap_left].to_f
      gap_right   = @params[:gap_right].to_f
      gap_top     = @params[:gap_top].to_f
      gap_bottom  = @params[:gap_bottom].to_f
      fixed_sizes = @params[:fixed_sizes] || []
      custom_names = @params[:custom_names] || []

      w_mm = @dims_mm[:width]
      d_mm = @dims_mm[:depth]
      h_mm = @dims_mm[:height]

      start_x = @bb.min.x
      start_y = @bb.min.y
      start_z = @bb.min.z

      plane = @selected_edge_info[:plane]
      direction = @selected_edge_info[:direction]

      boxes = []

      case plane
      when :front_back
        avail_w = w_mm - (gap_left + gap_right)
        avail_h = h_mm - (gap_top + gap_bottom)
        return nil if avail_w <= 0 || avail_h <= 0

        if direction == "Width"
          widths = calculate_segment_sizes(avail_w, n, gap_between, fixed_sizes)
          return nil unless widths
          cur_x = gap_left
          n.times do |i|
            fw = widths[i]
            x0 = start_x + cur_x.mm
            x1 = x0 + fw.mm
            y0 = start_y
            y1 = y0 + t.mm
            z0 = start_z + gap_bottom.mm
            z1 = z0 + avail_h.mm
            boxes << {
              name: FurnitureTools.resolve_item_name(custom_names[i], "Фасад #{i + 1}"),
              x0: x0, y0: y0, z0: z0, x1: x1, y1: y1, z1: z1,
              origin: [cur_x.mm, 0.0, gap_bottom.mm],
              size_x: fw.mm, size_y: t.mm, size_z: avail_h.mm
            }
            cur_x += fw + gap_between
          end
        else
          heights = calculate_segment_sizes(avail_h, n, gap_between, fixed_sizes)
          return nil unless heights
          cur_z = gap_bottom
          n.times do |i|
            fh = heights[i]
            x0 = start_x + gap_left.mm
            x1 = x0 + avail_w.mm
            y0 = start_y
            y1 = y0 + t.mm
            z0 = start_z + cur_z.mm
            z1 = z0 + fh.mm
            boxes << {
              name: FurnitureTools.resolve_item_name(custom_names[i], "Фасад #{i + 1} (шухляда)"),
              x0: x0, y0: y0, z0: z0, x1: x1, y1: y1, z1: z1,
              origin: [gap_left.mm, 0.0, cur_z.mm],
              size_x: avail_w.mm, size_y: t.mm, size_z: fh.mm
            }
            cur_z += fh + gap_between
          end
        end

      when :left_right
        avail_w = d_mm - (gap_left + gap_right)
        avail_h = h_mm - (gap_top + gap_bottom)
        return nil if avail_w <= 0 || avail_h <= 0

        if direction == "Width"
          widths = calculate_segment_sizes(avail_w, n, gap_between, fixed_sizes)
          return nil unless widths
          cur_y = gap_left
          n.times do |i|
            fw = widths[i]
            x0 = start_x
            x1 = x0 + t.mm
            y0 = start_y + cur_y.mm
            y1 = y0 + fw.mm
            z0 = start_z + gap_bottom.mm
            z1 = z0 + avail_h.mm
            boxes << {
              name: FurnitureTools.resolve_item_name(custom_names[i], "Фасад #{i + 1}"),
              x0: x0, y0: y0, z0: z0, x1: x1, y1: y1, z1: z1,
              origin: [0.0, cur_y.mm, gap_bottom.mm],
              size_x: t.mm, size_y: fw.mm, size_z: avail_h.mm
            }
            cur_y += fw + gap_between
          end
        else
          heights = calculate_segment_sizes(avail_h, n, gap_between, fixed_sizes)
          return nil unless heights
          cur_z = gap_bottom
          n.times do |i|
            fh = heights[i]
            x0 = start_x
            x1 = x0 + t.mm
            y0 = start_y + gap_left.mm
            y1 = y0 + avail_w.mm
            z0 = start_z + cur_z.mm
            z1 = z0 + fh.mm
            boxes << {
              name: FurnitureTools.resolve_item_name(custom_names[i], "Фасад #{i + 1} (шухляда)"),
              x0: x0, y0: y0, z0: z0, x1: x1, y1: y1, z1: z1,
              origin: [0.0, gap_left.mm, cur_z.mm],
              size_x: t.mm, size_y: avail_w.mm, size_z: fh.mm
            }
            cur_z += fh + gap_between
          end
        end

      when :horizontal
        avail_w = w_mm - (gap_left + gap_right)
        avail_d = d_mm - (gap_top + gap_bottom)
        return nil if avail_w <= 0 || avail_d <= 0

        widths = calculate_segment_sizes(avail_w, n, gap_between, fixed_sizes)
        return nil unless widths
        cur_x = gap_left
        n.times do |i|
          fw = widths[i]
          x0 = start_x + cur_x.mm
          x1 = x0 + fw.mm
          y0 = start_y + gap_bottom.mm
          y1 = y0 + avail_d.mm
          z0 = start_z
          z1 = z0 + t.mm
          boxes << {
            name: FurnitureTools.resolve_item_name(custom_names[i], "Фасад #{i + 1}"),
            x0: x0, y0: y0, z0: z0, x1: x1, y1: y1, z1: z1,
            origin: [cur_x.mm, gap_bottom.mm, 0.0],
            size_x: fw.mm, size_y: avail_d.mm, size_z: t.mm
          }
          cur_x += fw + gap_between
        end

      when :horizontal_y
        avail_w = w_mm - (gap_left + gap_right)
        avail_d = d_mm - (gap_top + gap_bottom)
        return nil if avail_w <= 0 || avail_d <= 0

        depths = calculate_segment_sizes(avail_d, n, gap_between, fixed_sizes)
        return nil unless depths
        cur_y = gap_bottom
        n.times do |i|
          fd = depths[i]
          x0 = start_x + gap_left.mm
          x1 = x0 + avail_w.mm
          y0 = start_y + cur_y.mm
          y1 = y0 + fd.mm
          z0 = start_z
          z1 = z0 + t.mm
          boxes << {
            name: FurnitureTools.resolve_item_name(custom_names[i], "Фасад #{i + 1}"),
            x0: x0, y0: y0, z0: z0, x1: x1, y1: y1, z1: z1,
            origin: [gap_left.mm, cur_y.mm, 0.0],
            size_x: avail_w.mm, size_y: fd.mm, size_z: t.mm
          }
          cur_y += fd + gap_between
        end
      end

      boxes
    end

    def box_wireframe_points(x0, y0, z0, x1, y1, z1)
      p1 = Geom::Point3d.new(x0, y0, z0)
      p2 = Geom::Point3d.new(x1, y0, z0)
      p3 = Geom::Point3d.new(x1, y1, z0)
      p4 = Geom::Point3d.new(x0, y1, z0)

      p5 = Geom::Point3d.new(x0, y0, z1)
      p6 = Geom::Point3d.new(x1, y0, z1)
      p7 = Geom::Point3d.new(x1, y1, z1)
      p8 = Geom::Point3d.new(x0, y1, z1)

      [
        p1, p2, p2, p3, p3, p4, p4, p1,
        p5, p6, p6, p7, p7, p8, p8, p5,
        p1, p5, p2, p6, p3, p7, p4, p8
      ]
    end

    def open_dialog
      close_dialog

      @dialog = UI::HtmlDialog.new(
        dialog_title: "Параметри фасадів",
        preferences_key: "FurnitureToolsDialog",
        scrollable: true,
        resizable: true,
        width: 440,
        height: 700,
        style: UI::HtmlDialog::STYLE_DIALOG
      )

      @dialog.set_html(FurnitureTools.build_dialog_html)

      @dialog.add_action_callback("ready") do |_ctx|
        send_init_data
      end

      @dialog.add_action_callback("update_params") do |_ctx, json_str|
        apply_data_from_js(json_str)
        Sketchup.active_model.active_view&.invalidate
      end

      @dialog.add_action_callback("apply") do |_ctx, json_str|
        apply_data_from_js(json_str)
        if generate_facades
          close_dialog
          Sketchup.active_model.select_tool(nil)
        end
      end

      @dialog.set_on_closed do
        @dialog = nil
        unless @generated
          Sketchup.active_model.select_tool(nil)
        end
      end

      @dialog.show
    end

    def apply_data_from_js(json_str)
      data = JSON.parse(json_str)
      n = [FurnitureTools.parse_int(data["num_facades"]), 1].max
      @params[:thickness]   = FurnitureTools.parse_float(data["thickness"])
      @params[:num_facades] = n
      @params[:gap_between] = FurnitureTools.parse_float(data["gap_between"])
      @params[:gap_left]    = FurnitureTools.parse_float(data["gap_left"])
      @params[:gap_right]   = FurnitureTools.parse_float(data["gap_right"])
      @params[:gap_top]     = FurnitureTools.parse_float(data["gap_top"])
      @params[:gap_bottom]  = FurnitureTools.parse_float(data["gap_bottom"])

      raw_fixed = Array(data["fixed_sizes"])
      @params[:fixed_sizes] = Array.new(n) do |i|
        v = raw_fixed[i]
        next nil if v.nil? || v.to_s.strip.empty?
        num = FurnitureTools.parse_float(v)
        num > 0.0 ? num : nil
      end

      raw_names = Array(data["custom_names"])
      @params[:custom_names] = Array.new(n) { |i| raw_names[i].to_s }
    end

    def send_init_data
      return unless @dialog
      payload = {
        mode: "facades",
        axis_label: @selected_edge_info[:axis_label],
        direction: @selected_edge_info[:direction],
        direction_label: direction_label(@selected_edge_info[:direction]),
        width: @dims_mm[:width].round(2),
        depth: @dims_mm[:depth].round(2),
        height: @dims_mm[:height].round(2),
        thickness: @params[:thickness],
        num_facades: @params[:num_facades],
        gap_between: @params[:gap_between],
        gap_left: @params[:gap_left],
        gap_right: @params[:gap_right],
        gap_top: @params[:gap_top],
        gap_bottom: @params[:gap_bottom],
        fixed_sizes: @params[:fixed_sizes],
        custom_names: @params[:custom_names]
      }
      @dialog.execute_script("initDialog(#{payload.to_json});")
    end

    def close_dialog
      if @dialog
        dlg = @dialog
        @dialog = nil
        dlg.close
      end
    end

    def generate_facades
      boxes = compute_facade_boxes
      if boxes.nil? || boxes.empty?
        UI.messagebox("Перевірте розміри зазорів, товщину та фіксовані розміри фасадів: сума не поміщається в проріз.")
        return false
      end

      model = Sketchup.active_model
      entities = model.active_entities
      start_x = @bb.min.x
      start_y = @bb.min.y
      start_z = @bb.min.z

      model.start_operation("Створення фасадів", true)

      boxes.each do |b|
        fg = entities.add_group
        fg.name = b[:name]
        ox, oy, oz = b[:origin]
        fg.transformation = Geom::Transformation.translation([start_x + ox, start_y + oy, start_z + oz])

        sx = b[:size_x]
        sy = b[:size_y]
        sz = b[:size_z]

        face = fg.entities.add_face([0, 0, 0], [sx, 0, 0], [sx, sy, 0], [0, sy, 0])
        face.reverse! if face.normal.z < 0
        face.pushpull(sz)
      end

      entities.erase_entities(@group) if @group && @group.valid?
      model.commit_operation
      @generated = true
      true
    end
  end

  def self.calculate
    model = Sketchup.active_model
    selection = model.selection

    if selection.length != 1 || !selection[0].is_a?(Sketchup::Group)
      UI.messagebox("⚠️ Будь ласка, виділіть один бокс або площину прорізу (групу) у проєкті!")
      return
    end

    bb = selection[0].bounds
    dims_mm = {
      width:  (bb.max.x - bb.min.x).to_mm.to_f,
      depth:  (bb.max.y - bb.min.y).to_mm.to_f,
      height: (bb.max.z - bb.min.z).to_mm.to_f
    }

    tool = FacadeEdgeTool.new(selection[0], dims_mm)
    model.select_tool(tool)
  end
end

unless file_loaded?(__FILE__)
  menu = UI.menu("Extensions")
  menu.add_item("Калькулятор полиць (3D)") { ShelfCalculator.calculate }
  menu.add_item("Калькулятор фасадів (3D)") { FacadeCalculator.calculate }
  menu.add_separator
  menu.add_item("Меблеві калькулятори: Перевірити оновлення") { FurnitureTools.check_for_updates(silent: false) }

  path = File.dirname(__FILE__)

  shelf_cmd = UI::Command.new("Калькулятор полиць (3D)") { ShelfCalculator.calculate }
  shelf_cmd.tooltip = "Обрати ребро боксу та налаштувати полиці/перегородки"
  s16 = File.join(path, "images", "shelf_16.png")
  s24 = File.join(path, "images", "shelf_24.png")
  shelf_cmd.small_icon = s16 if File.exist?(s16)
  shelf_cmd.large_icon = s24 if File.exist?(s24)

  facade_cmd = UI::Command.new("Калькулятор фасадів (3D)") { FacadeCalculator.calculate }
  facade_cmd.tooltip = "Обрати ребро боксу або площини та налаштувати фасади"
  f16 = File.join(path, "images", "facade_16.png")
  f24 = File.join(path, "images", "facade_24.png")
  facade_cmd.small_icon = f16 if File.exist?(f16)
  facade_cmd.large_icon = f24 if File.exist?(f24)

  toolbar = UI::Toolbar.new("Меблеві калькулятори")
  toolbar.add_item(shelf_cmd)
  toolbar.add_item(facade_cmd)
  toolbar.restore

  UI.start_timer(30.0, false) { FurnitureTools.check_for_updates(silent: true) }

  file_loaded(__FILE__)
end
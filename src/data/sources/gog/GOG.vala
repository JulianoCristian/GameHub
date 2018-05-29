using Gtk;
using Gee;
using GameHub.Utils;

namespace GameHub.Data.Sources.GOG
{
	public class GOG: GameSource
	{
		private const string CLIENT_ID = "46899977096215655";
		private const string CLIENT_SECRET = "9d85c43b1482497dbbce61f6e4aa173a433796eeae2ca8c5f6129f2dc4de46d9";
		private const string REDIRECT = "https%3A%2F%2Fembed.gog.com%2Fon_login_success%3Forigin%3Dclient";
		
		public override string name { get { return "GOG"; } }
		public override string icon { get { return "gog"; } }
		
		public string? user_id { get; protected set; }
		public string? user_name { get; protected set; }
		
		private string? user_auth_code = null;
		private string? user_token = null;
		private string? user_refresh_token = null;

		public override bool is_installed(bool refresh)
		{
			return true;
		}

		public override async bool install()
		{
			return true;
		}
		
		public override async bool authenticate()
		{
			return (yield get_auth_code()) && (yield get_token());
		}
		
		public override bool is_authenticated()
		{
			return user_token != null;
		}
		
		private async bool get_auth_code()
		{
			if(user_auth_code != null)
			{
				return true;
			}
			
			var wnd = new GameHub.UI.Windows.WebAuthWindow(this.name, @"https://auth.gog.com/auth?client_id=$(CLIENT_ID)&redirect_uri=$(REDIRECT)&response_type=code&layout=client2", "https://embed.gog.com/on_login_success?origin=client&code=");
			
			wnd.finished.connect(code =>
			{
				user_auth_code = code;
				Idle.add(get_auth_code.callback);
			});
			
			wnd.canceled.connect(() => Idle.add(get_auth_code.callback));
			
            wnd.set_size_request(550, 680);
			wnd.show_all();
			wnd.present();
			
			yield;
			
			return user_auth_code != null;
		}
		
		private async bool get_token()
		{
			if(user_token != null)
			{
				return true;
			}
			
			print("Fetching access token...\n");
			
			var url = @"https://auth.gog.com/token?client_id=$(CLIENT_ID)&client_secret=$(CLIENT_SECRET)&grant_type=authorization_code&redirect_uri=$(REDIRECT)&code=$(user_auth_code)";
			var root = yield Parser.parse_remote_json_file_async(url);
			user_token = root.get_string_member("access_token");
			user_refresh_token = root.get_string_member("refresh_token");
			user_id = root.get_string_member("user_id");
			
			return user_token != null;
		}
		
		private async bool refresh_token()
		{
			if(user_token == null)
			{
				return true;
			}
			
			var url = @"https://auth.gog.com/token?client_id=$(CLIENT_ID)&client_secret=$(CLIENT_SECRET)&grant_type=refresh_token&refresh_token=$(user_refresh_token)";
			var root = yield Parser.parse_remote_json_file_async(url);
			user_token = root.get_string_member("access_token");
			user_refresh_token = root.get_string_member("refresh_token");
			user_id = root.get_string_member("user_id");
			
			return user_token != null;
		}

		private ArrayList<Game> games = new ArrayList<Game>();
		public override async ArrayList<Game> load_games(FutureResult<Game>? game_loaded = null)
		{
			if(user_id == null || user_token == null || games.size > 0)
			{
				return games;
			}
			
			var url = @"https://embed.gog.com/account/getFilteredProducts?mediaType=1";
			var root = yield Parser.parse_remote_json_file_async(url, "GET", user_token);
			
			var products = root.get_array_member("products");
			
			games.clear();
			
			foreach(var g in products.get_elements())
			{
				var game = new GOGGame(this, g.get_object());
				if(yield game.is_for_linux())
				{
					games.add(game);
					games_count = games.size;
					if(game_loaded != null) game_loaded(game);
				}
			}
			
			games_count = games.size;
			
			return games;
		}
	}
}
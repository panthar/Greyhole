<?php
/*
Copyright 2009-2012 Guillaume Boudreau, Andrew Hopkinson

This file is part of Greyhole.

Greyhole is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

Greyhole is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with Greyhole.  If not, see <http://www.gnu.org/licenses/>.
*/

class CancelBalanceCliRunner extends AbstractCliRunner {
	public function run() {
		db_query("DELETE FROM tasks WHERE action = 'balance'") or Log::log(CRITICAL, "Can't delete balance tasks: " . db_error());
		$this->log("All scheduled balance tasks have now been deleted.");
		$this->restart_service();
	}
}

?>
